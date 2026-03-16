// SunCameraService.swift
// SunCapture — 业务层

import Foundation
import ImageCaptureCore

/// 相机业务层
///
/// 负责：
/// - 设备会话管理
/// - 文件下载（带 async/await）
/// - 文件删除
/// - 把 Driver 事件流透传给上层
///
/// 使用示例：
/// ```swift
/// let service = SunCameraService()
///
/// for await event in service.events {
///     switch event {
///     case .deviceAdded(let cam): await service.open(cam)
///     case .fileAdded(let file): print(file.name ?? "")
///     default: break
///     }
/// }
/// ```
public actor SunCameraService {

    // MARK: - 公共

    /// 所有事件流（来自 Driver）
    public var events: AsyncStream<SunDeviceEvent> {
        driver.events
    }

    // MARK: - 私有

    private let driver = SunCameraDriver()

    // MARK: - Init

    public init() {
        driver.startBrowsing()
    }

    // MARK: - 设备管理

    /// 打开相机会话
    public func open(_ device: ICCameraDevice) {
        driver.openSession(device)
    }

    /// 关闭相机会话
    public func close(_ device: ICCameraDevice) {
        driver.closeSession(device)
    }

    // MARK: - 文件删除

    /// 删除一组文件
    public func delete(_ files: [ICCameraFile], from device: ICCameraDevice) {
        driver.deleteFiles(files, from: device)
    }

    // MARK: - 缩略图 / 元数据

    /// 手动请求缩略图
    public func requestThumbnail(for file: ICCameraFile) {
        driver.requestThumbnail(for: file)
    }

    /// 手动请求一组文件的缩略图
    public func requestThumbnails(for files: [ICCameraFile]) {
        files.forEach { driver.requestThumbnail(for: $0) }
    }

    /// 手动请求元数据
    public func requestMetadata(for file: ICCameraFile) {
        driver.requestMetadata(for: file)
    }

    /// 检查设备是否连接
    public func isConnected(_ device: ICCameraDevice) -> Bool {
        device.hasOpenSession
    }
}

// MARK: - ObjC Download Helper（Continuation 桥接）

/// 内部用：把 ObjC selector 回调桥接到 Swift Continuation
final class SunDownloadHelper: NSObject, ICCameraDeviceDownloadDelegate, @unchecked Sendable {

    private let file: ICCameraFile
    private let dir : URL
    private let cont: CheckedContinuation<URL, Error>

    init(file: ICCameraFile, dir: URL, cont: CheckedContinuation<URL, Error>) {
        self.file = file
        self.dir  = dir
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
