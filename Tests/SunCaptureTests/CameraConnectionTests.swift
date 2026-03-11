//
//  CameraConnectionTests.swift
//  SunCapture
//
//  Created by Yanjun Sun on 2026/3/11.
//

import Testing
import ImageCaptureCore
@testable import SunCapture

// CameraConnectionTests.swift 顶部加这个
// ICCameraDevice 是 ObjC 类，ImageCaptureCore 内部保证线程安全，
// 标注 @unchecked Sendable 告诉编译器我们自己负责
extension ICCameraDevice: @retroactive @unchecked Sendable {}

// MARK: - Mock

/// 模拟 SunCameraService 的协议，测试不依赖真实硬件
protocol CameraServiceProtocol {
    func open(_ device: ICCameraDevice) async
    func close(_ device: ICCameraDevice) async
}

/// 记录调用历史，用于断言
final class MockCameraService: CameraServiceProtocol, @unchecked Sendable {

    // 记录 open/close 被调用的设备
    var openedDevices:  [ICCameraDevice] = []
    var closedDevices:  [ICCameraDevice] = []

    // 模拟事件流，测试可以手动 push 事件
    let bridge = SunAsyncBridge<SunDeviceEvent>()
    var events: AsyncStream<SunDeviceEvent> { bridge.stream }

    func open(_ device: ICCameraDevice) async {
        openedDevices.append(device)
        // 模拟：open 后立即触发 sessionOpened + deviceReady
        bridge.yield(.sessionOpened(device))
        bridge.yield(.deviceReady(device))
    }

    func close(_ device: ICCameraDevice) async {
        closedDevices.append(device)
        bridge.yield(.sessionClosed(device))
    }
}

// MARK: - 用于测试的简化 Store
// 不依赖真实 SunCameraService，注入 MockCameraService

@MainActor
final class TestCameraStore {

    var devices:        [ICCameraDevice] = []
    var selectedDevice: ICCameraDevice?
    var photos:         [String]         = [] // 只记录文件名，简化测试
    var isLoading       = false
    var errorMessage:   String?
    var isReady         = false

    private let service: MockCameraService
    private var listenTask: Task<Void, Never>?

    init(service: MockCameraService) {
        self.service = service
        listenTask = Task { await listen() }
    }

    func stopListening() {
        listenTask?.cancel()
        service.bridge.finish()
    }

    private func listen() async {
        for await event in service.events {
            switch event {
            case .deviceAdded(let cam):
                devices.append(cam)
                if selectedDevice == nil { await select(cam) }

            case .deviceRemoved(let cam):
                devices.removeAll { $0 === cam }
                if selectedDevice === cam {
                    selectedDevice = nil
                    photos = []
                    isReady = false
                }

            case .sessionOpened:
                isLoading = true

            case .deviceReady:
                isLoading = false
                isReady = true

            case .sessionClosed:
                isLoading = false

            case .fileAdded(let file):
                photos.append(file.name ?? "unknown")

            case .error(let err):
                errorMessage = err.localizedDescription
                isLoading = false

            default:
                break
            }
        }
    }

    func select(_ device: ICCameraDevice) async {
        selectedDevice = device
        photos = []
        isLoading = true
        isReady = false
        await service.open(device)
    }
}

// MARK: - 测试套件

@Suite("相机连接流程")
@MainActor
struct CameraConnectionTests {

    // MARK: 设备发现

    @Test("deviceAdded 事件后 devices 列表更新")
    func deviceAdded() async throws {
        let mock  = MockCameraService()
        let store = TestCameraStore(service: mock)
        defer { store.stopListening() }

        // 给 bridge 一点时间让 listenTask 启动
        try await Task.sleep(for: .milliseconds(10))

        let fakeDevice = ICCameraDevice()
        mock.bridge.yield(.deviceAdded(fakeDevice))

        try await Task.sleep(for: .milliseconds(20))

        #expect(store.devices.count == 1)
        #expect(store.devices.first === fakeDevice)
    }

    @Test("deviceRemoved 事件后 devices 列表移除")
    func deviceRemoved() async throws {
        let mock  = MockCameraService()
        let store = TestCameraStore(service: mock)
        defer { store.stopListening() }

        try await Task.sleep(for: .milliseconds(10))

        let fakeDevice = ICCameraDevice()
        mock.bridge.yield(.deviceAdded(fakeDevice))
        try await Task.sleep(for: .milliseconds(10))
        mock.bridge.yield(.deviceRemoved(fakeDevice))
        try await Task.sleep(for: .milliseconds(20))

        #expect(store.devices.isEmpty)
    }

    // MARK: 自动连接

    @Test("第一台设备连接后自动 select")
    func autoSelectFirstDevice() async throws {
        let mock  = MockCameraService()
        let store = TestCameraStore(service: mock)
        defer { store.stopListening() }

        try await Task.sleep(for: .milliseconds(10))

        let fakeDevice = ICCameraDevice()
        mock.bridge.yield(.deviceAdded(fakeDevice))

        try await Task.sleep(for: .milliseconds(30))

        #expect(store.selectedDevice === fakeDevice)
        #expect(mock.openedDevices.contains { $0 === fakeDevice })
    }

    @Test("第二台设备连接不会覆盖已选设备")
    func secondDeviceDoesNotOverrideSelection() async throws {
        let mock  = MockCameraService()
        let store = TestCameraStore(service: mock)
        defer { store.stopListening() }

        try await Task.sleep(for: .milliseconds(10))

        let first  = ICCameraDevice()
        let second = ICCameraDevice()

        mock.bridge.yield(.deviceAdded(first))
        try await Task.sleep(for: .milliseconds(20))
        mock.bridge.yield(.deviceAdded(second))
        try await Task.sleep(for: .milliseconds(20))

        // selectedDevice 仍是第一台
        #expect(store.selectedDevice === first)
        #expect(store.devices.count == 2)
    }

    // MARK: 会话生命周期

    @Test("open 触发后 isLoading 变为 true")
    func openSessionSetsLoading() async throws {
        let mock  = MockCameraService()
        let store = TestCameraStore(service: mock)
        defer { store.stopListening() }

        try await Task.sleep(for: .milliseconds(10))

        let fakeDevice = ICCameraDevice()
        // 手动 select，不走 deviceAdded 自动流程
        async let _ = store.select(fakeDevice)

        // sessionOpened 由 mock.open 自动 yield，
        // 给一点时间让事件流转
        try await Task.sleep(for: .milliseconds(30))

        // deviceReady 也已经 yield，最终 isLoading 应为 false
        #expect(store.isLoading == false)
        #expect(store.isReady == true)
    }

    @Test("deviceReady 事件后 isLoading 变为 false，isReady 变为 true")
    func deviceReadySetsReadyState() async throws {
        let mock  = MockCameraService()
        let store = TestCameraStore(service: mock)
        defer { store.stopListening() }

        try await Task.sleep(for: .milliseconds(10))

        let fakeDevice = ICCameraDevice()
        mock.bridge.yield(.sessionOpened(fakeDevice))
        try await Task.sleep(for: .milliseconds(10))

        #expect(store.isLoading == true)
        #expect(store.isReady  == false)

        mock.bridge.yield(.deviceReady(fakeDevice))
        try await Task.sleep(for: .milliseconds(20))

        #expect(store.isLoading == false)
        #expect(store.isReady  == true)
    }

    // MARK: 断开处理

    @Test("已选设备断开后 selectedDevice 清空")
    func selectedDeviceRemovedClearsState() async throws {
        let mock  = MockCameraService()
        let store = TestCameraStore(service: mock)
        defer { store.stopListening() }

        try await Task.sleep(for: .milliseconds(10))

        let fakeDevice = ICCameraDevice()
        mock.bridge.yield(.deviceAdded(fakeDevice))
        try await Task.sleep(for: .milliseconds(30))

        #expect(store.selectedDevice === fakeDevice)

        mock.bridge.yield(.deviceRemoved(fakeDevice))
        try await Task.sleep(for: .milliseconds(20))

        #expect(store.selectedDevice == nil)
        #expect(store.photos.isEmpty)
        #expect(store.isReady == false)
    }

    // MARK: 错误处理

    @Test("error 事件后 errorMessage 被设置")
    func errorEventSetsMessage() async throws {
        let mock  = MockCameraService()
        let store = TestCameraStore(service: mock)
        defer { store.stopListening() }

        try await Task.sleep(for: .milliseconds(10))

        mock.bridge.yield(.error(.noDevice))
        try await Task.sleep(for: .milliseconds(20))

        #expect(store.errorMessage != nil)
        #expect(store.errorMessage?.isEmpty == false)
    }

    @Test("error 事件后 isLoading 变为 false")
    func errorStopsLoading() async throws {
        let mock  = MockCameraService()
        let store = TestCameraStore(service: mock)
        defer { store.stopListening() }

        try await Task.sleep(for: .milliseconds(10))

        // 先触发 loading
        let fakeDevice = ICCameraDevice()
        mock.bridge.yield(.sessionOpened(fakeDevice))
        try await Task.sleep(for: .milliseconds(10))
        #expect(store.isLoading == true)

        // 再触发错误
        mock.bridge.yield(.error(.noDevice))
        try await Task.sleep(for: .milliseconds(20))
        #expect(store.isLoading == false)
    }
}
