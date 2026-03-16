// SunDeviceEvent.swift
// SunCapture — 事件定义

import Foundation
import ImageCaptureCore
import AppKit

/// 相机设备产生的所有事件
public enum SunDeviceEvent: @unchecked Sendable {

    // MARK: - 设备生命周期
    /// 新设备连接
    case deviceAdded(ICCameraDevice)
    /// 设备断开
    case deviceRemoved(ICCameraDevice)

    // MARK: - 会话
    /// 会话已打开
    case sessionOpened(ICCameraDevice)
    /// 会话已关闭
    case sessionClosed(ICCameraDevice)
    /// 文件目录加载完毕，设备就绪
    case deviceReady(ICCameraDevice)

    // MARK: - 文件
    /// 新增文件（首次枚举 + 热插拔）
    case fileAdded(ICCameraFile)
    /// 文件移除
    case fileRemoved(ICCameraFile)
    /// 文件重命名（ICCameraFile.name 已自动更新）
    case fileRenamed(ICCameraFile)

    // MARK: - 媒体数据
    /// 缩略图就绪
    case thumbnailReady(file: ICCameraFile, image: CGImage)
    /// 元数据就绪
    case metadataReady(file: ICCameraFile, metadata: SunPhotoMetadata)

    // MARK: - 访问限制
    /// 相机启用访问限制
    case accessRestricted(ICDevice)
    
    /// 访问限制已解除
    case accessUnrestricted(ICDevice)

    // MARK: - 错误
    /// 会话 / 设备错误
    case error(SunCaptureError)
}
