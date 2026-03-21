// SunCameraDriver.swift
// SunCapture — ImageCaptureCore 驱动层

import Foundation
import ImageCaptureCore
import AppKit

/// 底层 ImageCaptureCore 驱动
///
/// 职责：
/// - 封装 ICDeviceBrowser / ICCameraDevice delegate
/// - 通过 ``SunEventMulticast`` 把事件广播给任意多个 `AsyncStream`（避免「抢事件」）
/// - 不持有业务状态；会话确认点由 ``SunCameraService`` 实现
///
/// ## 线程说明
/// ImageCaptureCore 的 delegate 回调**不保证**在主线程；本类型只在回调里做 O(1) 广播，重逻辑应放在 actor 业务层。
public final class SunCameraDriver: NSObject, @unchecked Sendable {

    // MARK: - 公共事件流

    /// 设备 / 文件事件。每次访问都会得到**新的**订阅（多消费者安全）。
    public var events: AsyncStream<SunDeviceEvent> {
        eventMulticast.subscribe()
    }

    // MARK: - 私有

    private let eventMulticast = SunEventMulticast<SunDeviceEvent>()

    nonisolated(unsafe) private var browser: ICDeviceBrowser?

    // MARK: - Init / Deinit

    public override init() {
        super.init()
    }

    deinit {
        browser?.stop()
        browser?.delegate = nil
    }

    // MARK: - 设备浏览

    /// 开始扫描连接的相机设备
    public func startBrowsing() {
        let b = ICDeviceBrowser()
        b.delegate = self
        b.browsedDeviceTypeMask = .camera
        b.start()
        browser = b
    }

    /// 停止扫描
    public func stopBrowsing() {
        browser?.stop()
        browser?.delegate = nil
        browser = nil
    }

    // MARK: - 设备会话（仅下发请求；确认点在 Service）

    /// 绑定 delegate 并请求打开会话（不等待完成）
    public func bindAndRequestOpenSession(_ device: ICCameraDevice) {
        device.delegate = self
        device.requestOpenSession()
    }

    /// 请求关闭会话（不等待完成）
    public func requestCloseSession(_ device: ICCameraDevice) {
        device.requestCloseSession()
    }

    // MARK: - 文件操作

    /// 删除文件
    public func deleteFiles(_ files: [ICCameraFile], from device: ICCameraDevice) {
        device.requestDeleteFiles(files)
    }

    /// 请求缩略图
    public func requestThumbnail(for file: ICCameraFile) {
        file.requestThumbnail()
    }

    /// 请求元数据
    public func requestMetadata(for file: ICCameraFile) {
        file.requestMetadata()
    }

    // MARK: - 内部事件推送

    fileprivate func emit(_ event: SunDeviceEvent) {
        eventMulticast.broadcast(event)
    }
}

// MARK: - ICDeviceBrowserDelegate

extension SunCameraDriver: ICDeviceBrowserDelegate {

    public func deviceBrowser(_ browser: ICDeviceBrowser,
                              didAdd device: ICDevice,
                              moreComing: Bool) {
        guard let cam = device as? ICCameraDevice else { return }
        emit(.deviceAdded(cam))
    }

    public func deviceBrowser(_ browser: ICDeviceBrowser,
                              didRemove device: ICDevice,
                              moreGoing: Bool) {
        guard let cam = device as? ICCameraDevice else { return }
        emit(.deviceRemoved(cam))
    }
}

// MARK: - ICCameraDeviceDelegate

extension SunCameraDriver: ICCameraDeviceDelegate {

    // 文件目录加载完毕
    public func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {
        print("✅ deviceReady @ \(Date()), contents count: \(device.contents?.count ?? -1)")
        emit(.deviceReady(device))
    }

    // 会话打开
    public func device(_ device: ICDevice, didOpenSessionWithError error: (any Error)?) {
        if let error {
            emit(.error(.sessionFailed(error)))
        } else if let cam = device as? ICCameraDevice {
            emit(.sessionOpened(cam))
        }
    }

    // 会话关闭
    public func device(_ device: ICDevice, didCloseSessionWithError error: (any Error)?) {
        if let error {
            emit(.error(.sessionFailed(error)))
        } else if let cam = device as? ICCameraDevice {
            emit(.sessionClosed(cam))
        }
    }

    // 新增文件
    public func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {
        for item in items {
            guard let file = item as? ICCameraFile else { continue }
            print("📥 fileAdded: \(file.name ?? "nil") @ \(Date())")
            emit(.fileAdded(file))
            file.requestThumbnail()
        }
    }

    // 移除文件
    public func cameraDevice(_ camera: ICCameraDevice, didRemove items: [ICCameraItem]) {
        for item in items {
            guard let file = item as? ICCameraFile else { continue }
            emit(.fileRemoved(file))
        }
    }

    // 文件重命名
    public func cameraDevice(_ camera: ICCameraDevice, didRenameItems items: [ICCameraItem]) {
        for item in items {
            guard let file = item as? ICCameraFile else { continue }
            emit(.fileRenamed(file))
        }
    }

    // 缩略图就绪
    public func cameraDevice(_ camera: ICCameraDevice,
                             didReceiveThumbnail thumbnail: CGImage?,
                             for item: ICCameraItem,
                             error: (any Error)?) {
        guard let file = item as? ICCameraFile else { return }
        if let error {
            emit(.error(.thumbnailFailed(file, error)))
            return
        }
        guard let cg = thumbnail else { return }
        emit(.thumbnailReady(file: file, image: cg))
    }

    // 元数据就绪
    public func cameraDevice(_ camera: ICCameraDevice,
                             didReceiveMetadata metadata: [AnyHashable: Any]?,
                             for item: ICCameraItem,
                             error: (any Error)?) {
        guard let file = item as? ICCameraFile,
              let meta = metadata else { return }
        emit(.metadataReady(file: file, metadata: SunPhotoMetadata(from: meta)))
    }

    // 访问限制
    public func cameraDeviceDidEnableAccessRestriction(_ device: ICDevice) {
        emit(.accessRestricted(device))
    }

    public func cameraDeviceDidRemoveAccessRestriction(_ device: ICDevice) {
        emit(.accessUnrestricted(device))
    }

    // 设备断开
    public func didRemove(_ device: ICDevice) {
        guard let cam = device as? ICCameraDevice else { return }
        emit(.deviceRemoved(cam))
    }

    public func cameraDeviceDidChangeCapability(_ camera: ICCameraDevice) {}
    public func cameraDevice(_ camera: ICCameraDevice, didReceivePTPEvent eventData: Data) {}
}

extension SunCameraDriver {
    public func connectedDevices() -> [ICCameraDevice] {
        (browser?.devices ?? []).compactMap { $0 as? ICCameraDevice }
    }
}
