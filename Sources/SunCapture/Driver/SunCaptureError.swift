// SunCaptureError.swift
// SunCapture — 错误类型

import Foundation
@preconcurrency import ImageCaptureCore

/// SunCapture 统一错误类型
public enum SunCaptureError: LocalizedError, Sendable {
    
    /// 没有已连接的相机设备
    case noDevice

    /// 操作超时（带可观测的语义标签，便于日志与崩溃聚合）
    case operationTimedOut(operation: String)

    /// 设备已断开（delegate 延迟或未触发时，业务层仍应能失败得明确）
    case deviceDisconnected(uuid: String)

    /// 会话已开但目录/能力尚未达到可安全操作业务的确认点
    case sessionNotReady(uuid: String)

    /// 任务被取消（通常是 close / 拔线触发的合并取消）
    case cancelled
    
    /// 会话打开 / 关闭失败
    case sessionFailed(any Error)
    
    /// 文件下载失败
    case downloadFailed(ICCameraFile, any Error)
    
    /// 缩略图获取失败
    case thumbnailFailed(ICCameraFile, any Error)
    
    /// 下载目录创建失败
    case directoryCreationFailed(URL, any Error)
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        case .noDevice:
            return "没有已连接的相机设备"
        case .operationTimedOut(let op):
            return "操作超时：\(op)"
        case .deviceDisconnected(let uuid):
            return "设备已断开：\(uuid)"
        case .sessionNotReady(let uuid):
            return "会话尚未就绪（目录未确认）：\(uuid)"
        case .cancelled:
            return "操作已取消"
        case .sessionFailed(let e):
            return "会话失败：\(e.localizedDescription)"
        case .downloadFailed(let f, let e):
            return "下载文件 \(f.name ?? "unknown") 失败：\(e.localizedDescription)"
        case .thumbnailFailed(let f, let e):
            return "获取缩略图失败 \(f.name ?? "unknown")：\(e.localizedDescription)"
        case .directoryCreationFailed(let url, let e):
            return "创建目录失败 \(url.path)：\(e.localizedDescription)"
        }
    }
}
