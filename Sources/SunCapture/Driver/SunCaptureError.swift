// SunCaptureError.swift
// SunCapture — 错误类型

import Foundation
@preconcurrency import ImageCaptureCore

/// SunCapture 统一错误类型
public enum SunCaptureError: LocalizedError, Sendable {
    
    /// 没有已连接的相机设备
    case noDevice
    
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
