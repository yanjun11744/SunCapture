// SunCameraService.swift
// SunCapture — 业务层（Actor + 会话状态机）

import Foundation
import ImageCaptureCore

// MARK: - ICCameraDevice 并发句柄（Swift 6 / `TaskGroup` 需要 Sendable 边界）

/// ImageCaptureCore 设备引用不是 `Sendable`；Apple 框架在内部保证 ObjC 桥接对象的线程安全。
/// 仅在「轮询确认点」子任务中使用，避免把非 Sendable 引用直接捕获进 `@Sendable` 闭包。
private final class ICCameraHandle: @unchecked Sendable {
    let device: ICCameraDevice
    init(_ device: ICCameraDevice) { self.device = device }
}

// MARK: - 策略 / 状态（对外可观测，避免调用方猜）

/// 打开 / 关闭 / 轮询等超时与重试策略（可按机型调参）。
public struct SunCameraSessionPolicy: Sendable {

    /// `requestOpenSession` 后，等待「会话已开」确认点的上限
    public var openSessionTimeout: Duration

    /// 会话已开后，等待「目录就绪」确认点的上限（空卡也可能很快 ready）
    public var catalogReadyTimeout: Duration

    /// `requestCloseSession` 后，等待「会话已关」确认点的上限
    public var closeSessionTimeout: Duration

    /// 轮询 `hasOpenSession` / `contents` 的间隔（delegate 卡死时的兜底）
    public var pollInterval: Duration

    /// 除首次外，额外重发 `requestOpenSession` 的次数（针对偶发无回调 / PTP 卡死）
    public var openCommandRetries: Int

    /// 重试之间的退避
    public var retryDelay: Duration

    /// 连续 `close` → `open` 时的短暂间隔，避免框架层抖动
    public var operationDebounce: Duration

    /// 等待删除在事件流上确认的超时
    public var deleteConfirmationTimeout: Duration

    public static let `default` = SunCameraSessionPolicy(
        openSessionTimeout: .seconds(20),
        catalogReadyTimeout: .seconds(60),
        closeSessionTimeout: .seconds(15),
        pollInterval: .milliseconds(200),
        openCommandRetries: 1,
        retryDelay: .milliseconds(400),
        operationDebounce: .zero,
        deleteConfirmationTimeout: .seconds(30)
    )

    public init(
        openSessionTimeout: Duration,
        catalogReadyTimeout: Duration,
        closeSessionTimeout: Duration,
        pollInterval: Duration,
        openCommandRetries: Int,
        retryDelay: Duration,
        operationDebounce: Duration,
        deleteConfirmationTimeout: Duration
    ) {
        self.openSessionTimeout = openSessionTimeout
        self.catalogReadyTimeout = catalogReadyTimeout
        self.closeSessionTimeout = closeSessionTimeout
        self.pollInterval = pollInterval
        self.openCommandRetries = openCommandRetries
        self.retryDelay = retryDelay
        self.operationDebounce = operationDebounce
        self.deleteConfirmationTimeout = deleteConfirmationTimeout
    }
}

/// 会话相位的粗粒度快照（用于 UI / 调试；权威确认仍以 `async` API 为准）。
public enum SunCameraSessionPhase: Sendable, Equatable {
    case idle
    case opening
    case sessionOpenPendingCatalog
    case ready
    case closing
}

/// 相机业务层（`actor`）：所有命令型 API 均提供 `async` 确认语义，避免「猜状态」。
///
/// ### 架构要点
/// - **多播事件**：内部泵与用户 `events` 并行订阅，互不抢事件。
/// - **会话状态机**：同一设备键的并发 `open` 会合并等待；`close` 会取消进行中的 `open`。
/// - **确认点**：`open` = 会话已开（delegate **或** `hasOpenSession` 轮询） ∧ 目录就绪（`deviceReady` **或** `contents != nil` 轮询）。
public actor SunCameraService {

    // MARK: - 公共

    /// 所有事件流（多播中的一路订阅）
    public var events: AsyncStream<SunDeviceEvent> {
        driver.events
    }

    // MARK: - 私有

    private let driver = SunCameraDriver()

    /// 已通过「目录就绪」确认点的设备（稳定设备键）
    private var readyCatalogDevices: Set<String> = []

    /// 并发 `open` 合并
    private var openInflight: [String: Task<Void, Error>] = [:]

    private var lifecyclePumpStarted = false

    /// 稳定设备键：优先 UUID；缺失时退化为对象标识（避免 `uuidString` 为可选时无法入表）。
    /// `nonisolated static`：可在 `TaskGroup` / delegate 回调路径安全调用，不依赖 actor 状态。
    private nonisolated static func deviceKey(_ device: ICCameraDevice) -> String {
        if let s = device.uuidString, !s.isEmpty {
            return s
        }
        return "object:\(ObjectIdentifier(device))"
    }

    // MARK: - Init

    public init() {
        driver.startBrowsing()
        Task {
            await self.startLifecyclePumpIfNeeded()
        }
    }

    // MARK: - 浏览

    /// 停止扫描（一般无需调用；测试或省电场景可用）
    public func stopBrowsing() {
        driver.stopBrowsing()
    }

    // MARK: - 会话（确认点）

    /// 打开会话并等待**双重确认**：会话已开 + 目录就绪（或轮询兜底）。
    ///
    /// - Note: 已 ready 的设备会立即返回，不会重复 `requestOpenSession`。
    public func openSession(
        on device: ICCameraDevice,
        policy: SunCameraSessionPolicy = .default
    ) async throws {
        startLifecyclePumpIfNeeded()
        let key = Self.deviceKey(device)

        if readyCatalogDevices.contains(key) { return }

        if let existing = openInflight[key] {
            try await existing.value
            if readyCatalogDevices.contains(key) { return }
        }

        if policy.operationDebounce > .zero {
            try await Task.sleep(for: policy.operationDebounce)
        }

        let task = Task { try await self.performOpen(device: device, policy: policy) }
        openInflight[key] = task
        defer { openInflight[key] = nil }

        do {
            try await task.value
        } catch is CancellationError {
            throw SunCaptureError.cancelled
        } catch {
            readyCatalogDevices.remove(key)
            throw error
        }
    }

    /// 关闭会话并等待「已关」确认（`sessionClosed` 或 `hasOpenSession == false` 轮询兜底）。
    public func closeSession(
        on device: ICCameraDevice,
        policy: SunCameraSessionPolicy = .default
    ) async {
        startLifecyclePumpIfNeeded()
        let key = Self.deviceKey(device)

        openInflight[key]?.cancel()
        openInflight[key] = nil
        readyCatalogDevices.remove(key)

        let isOpen = device.hasOpenSession
        guard isOpen else { return }

        driver.requestCloseSession(device)

        try? await confirmSessionClosed(device: device, poll: policy.pollInterval, deadline: policy.closeSessionTimeout)
    }

    /// 当前会话相位（`async`：需要读取 `hasOpenSession` 时走 MainActor）
    public func sessionPhase(for device: ICCameraDevice) async -> SunCameraSessionPhase {
        let key = Self.deviceKey(device)
        if openInflight[key] != nil { return .opening }

        let open = device.hasOpenSession
        if !open { return .idle }
        if readyCatalogDevices.contains(key) { return .ready }
        return .sessionOpenPendingCatalog
    }

    /// `hasOpenSession` 的明确查询（不要直接读 device 猜状态）
    public func isSessionOpen(_ device: ICCameraDevice) async -> Bool {
        device.hasOpenSession
    }

    /// 是否已通过本库的「目录就绪」确认点
    public func isCatalogReady(_ device: ICCameraDevice) async -> Bool {
        readyCatalogDevices.contains(Self.deviceKey(device))
    }

    // MARK: - 文件删除（等待 delegate 确认或超时）

    /// 删除文件并等待 `fileRemoved` 事件确认（USB/PTP 慢时由超时暴露失败，而不是静默成功）。
   // SunCameraService.deleteFiles
    public func deleteFiles(
        _ files: [ICCameraFile],
        from device: ICCameraDevice,
        policy: SunCameraSessionPolicy = .default
    ) async throws {
        try await ensureCatalogReady(device: device, policy: policy)
        guard !files.isEmpty else { return }

        final class PendingNamesBox: @unchecked Sendable {
            var names: Set<String>
            init(_ names: Set<String>) { self.names = names }
        }
        let pendingBox = PendingNamesBox(Set(files.compactMap(\.name)))
        let devKey = Self.deviceKey(device)

        // ✅ 先订阅事件流，再发删除命令，消除竞争窗口
        let eventStream = driver.events
        driver.deleteFiles(files, from: device)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await event in eventStream {
                    switch event {
                    case .fileRemoved(let f):
                        if let name = f.name {
                            pendingBox.names.remove(name)
                            print("✅ fileRemoved: \(name), 剩余: \(pendingBox.names)")
                        }
                        if pendingBox.names.isEmpty { return }
                    case .deviceRemoved(let cam) where Self.deviceKey(cam) == devKey:
                        throw SunCaptureError.deviceDisconnected(uuid: devKey)
                    case .error(let err):
                        throw err
                    default:
                        continue
                    }
                }
                throw SunCaptureError.deviceDisconnected(uuid: devKey)
            }

            group.addTask {
                try await Task.sleep(for: policy.deleteConfirmationTimeout)
                throw SunCaptureError.operationTimedOut(operation: "deleteFiles.confirm")
            }

            try await group.next()!
            group.cancelAll()
        }
    }

    // MARK: - 缩略图 / 元数据（命令下发；结果仍在 `events`）

    public func requestThumbnail(for file: ICCameraFile) {
        driver.requestThumbnail(for: file)
    }

    public func requestThumbnails(for files: [ICCameraFile]) {
        files.forEach { driver.requestThumbnail(for: $0) }
    }

    public func requestMetadata(for file: ICCameraFile) {
        driver.requestMetadata(for: file)
    }

    // MARK: - 内部：生命周期泵（断开 / 关会话 → 清状态）

    private func startLifecyclePumpIfNeeded() {
        guard !lifecyclePumpStarted else { return }
        lifecyclePumpStarted = true

        let stream = driver.events
        Task {
            for await event in stream {
                self.handleLifecycleEvent(event)
            }
        }
    }

    private func handleLifecycleEvent(_ event: SunDeviceEvent) {
        switch event {
        case .deviceRemoved(let cam):
            let key = Self.deviceKey(cam)
            openInflight[key]?.cancel()
            openInflight[key] = nil
            readyCatalogDevices.remove(key)

        case .sessionClosed(let cam):
            readyCatalogDevices.remove(Self.deviceKey(cam))

        default:
            break
        }
    }
    
    public func connectedDevices() -> [ICCameraDevice] {
        driver.connectedDevices()
    }

    // MARK: - 内部：open 实现

    private func performOpen(device: ICCameraDevice, policy: SunCameraSessionPolicy) async throws {
        let key = Self.deviceKey(device)
        var lastError: Error?

        for attempt in 0...policy.openCommandRetries {
            do {
                try Task.checkCancellation()

                if attempt == 0 {
                    driver.bindAndRequestOpenSession(device)
                } else {
                    if policy.retryDelay > .zero {
                        try await Task.sleep(for: policy.retryDelay)
                    }
                    try await device.requestOpenSession()
                }

                try await confirmSessionOpen(device: device, poll: policy.pollInterval, deadline: policy.openSessionTimeout)
                try await confirmCatalogReady(device: device, poll: policy.pollInterval, deadline: policy.catalogReadyTimeout)

                readyCatalogDevices.insert(key)
                return

            } catch is CancellationError {
                throw SunCaptureError.cancelled
            } catch {
                lastError = error
            }
        }

        readyCatalogDevices.remove(key)
        throw lastError ?? SunCaptureError.operationTimedOut(operation: "openSession")
    }

    /// 「会话已开」确认点：delegate 与 `hasOpenSession` 二选一先到 + 总超时。
    private func confirmSessionOpen(
        device: ICCameraDevice,
        poll: Duration,
        deadline: Duration
    ) async throws {
        let key = Self.deviceKey(device)
        let handle = ICCameraHandle(device)
        let eventStream = driver.events          // ← 提前订阅

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await event in eventStream { // ← 用 eventStream
                    try Task.checkCancellation()
                    switch event {
                    case .sessionOpened(let cam) where Self.deviceKey(cam) == key:
                        return
                    case .error(let err):
                        throw err
                    case .deviceRemoved(let cam) where Self.deviceKey(cam) == key:
                        throw SunCaptureError.deviceDisconnected(uuid: key)
                    default:
                        continue
                    }
                }
                throw SunCaptureError.deviceDisconnected(uuid: key)
            }
            // 轮询和超时 task 不变
            group.addTask {
                while !Task.isCancelled {
                    if handle.device.hasOpenSession { return }
                    try await Task.sleep(for: poll)
                }
                throw SunCaptureError.cancelled
            }
            group.addTask {
                try await Task.sleep(for: deadline)
                throw SunCaptureError.operationTimedOut(operation: "openSession")
            }
            try await group.next()!
            group.cancelAll()
        }
    }


    /// 「目录就绪」确认点：`deviceReady` 或 `contents != nil`（空卡也可能是空数组，但非 nil 即视为可枚举完成）
    private func confirmCatalogReady(
        device: ICCameraDevice,
        poll: Duration,
        deadline: Duration
    ) async throws {
        let key = Self.deviceKey(device)
        let handle = ICCameraHandle(device)
        let eventStream = driver.events          // ← 提前订阅

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await event in eventStream {
                    try Task.checkCancellation()
                    switch event {
                    case .deviceReady(let cam) where Self.deviceKey(cam) == key:
                        return
                    case .deviceRemoved(let cam) where Self.deviceKey(cam) == key:
                        throw SunCaptureError.deviceDisconnected(uuid: key)
                    case .error(let err):
                        throw err
                    default:
                        continue
                    }
                }
                throw SunCaptureError.deviceDisconnected(uuid: key)
            }
            group.addTask {
                while !Task.isCancelled {
                    if handle.device.hasOpenSession && handle.device.contents != nil { return }
                    try await Task.sleep(for: poll)
                }
                throw SunCaptureError.cancelled
            }
            group.addTask {
                try await Task.sleep(for: deadline)
                throw SunCaptureError.operationTimedOut(operation: "catalogReady")
            }
            try await group.next()!
            group.cancelAll()
        }
    }

    private func confirmSessionClosed(
        device: ICCameraDevice,
        poll: Duration,
        deadline: Duration
    ) async throws {
        let key = Self.deviceKey(device)
        let handle = ICCameraHandle(device)
        let eventStream = driver.events          // ← 提前订阅

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await event in eventStream {
                    try Task.checkCancellation()
                    switch event {
                    case .sessionClosed(let cam) where Self.deviceKey(cam) == key:
                        return
                    case .deviceRemoved(let cam) where Self.deviceKey(cam) == key:
                        return
                    case .error(let err):
                        throw err
                    default:
                        continue
                    }
                }
                return  // 流意外结束视为已关闭（设备断开也算关闭成功）
            }
            group.addTask {
                while !Task.isCancelled {
                    if !handle.device.hasOpenSession { return }
                    try await Task.sleep(for: poll)
                }
                throw SunCaptureError.cancelled
            }
            group.addTask {
                try await Task.sleep(for: deadline)
                throw SunCaptureError.operationTimedOut(operation: "closeSession")
            }
            try await group.next()!
            group.cancelAll()
        }
    }

    // MARK: - 内部：业务前置条件

    /// 下载 / 删除等文件操作前调用：在尚未就绪时自动走完整 `openSession` 确认链。
    internal func ensureCatalogReady(
        device: ICCameraDevice,
        policy: SunCameraSessionPolicy = .default
    ) async throws {
        let key = Self.deviceKey(device)
        if readyCatalogDevices.contains(key) { return }
        try await openSession(on: device, policy: policy)
    }
}

// MARK: - ObjC Download Helper（Continuation 桥接）

/// 内部用：把 ObjC selector 回调桥接到 Swift Continuation
final class SunDownloadHelper: NSObject, ICCameraDeviceDownloadDelegate, @unchecked Sendable {

    private let file: ICCameraFile
    private let dir: URL
    private let cont: CheckedContinuation<URL, Error>

    init(file: ICCameraFile, dir: URL, cont: CheckedContinuation<URL, Error>) {
        self.file = file
        self.dir = dir
        self.cont = cont
    }

    @objc func done(_ f: ICCameraFile, error: Error?, contextInfo: UnsafeRawPointer?) {
        if let error {
            cont.resume(throwing: SunCaptureError.downloadFailed(f, error))
        } else {
            cont.resume(returning: dir.appendingPathComponent(f.name ?? "file"))
        }
    }
}
