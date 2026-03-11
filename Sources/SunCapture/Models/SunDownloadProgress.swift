// SunDownloadProgress.swift
// SunCapture — 下载进度模型

import Foundation

/// 批量下载进度
public struct SunDownloadProgress: Sendable {

    /// 总文件数
    public let total: Int

    /// 已完成数量
    public let completed: Int

    /// 当前正在下载的文件名
    public let currentFileName: String
    
    /// nil 表示成功
    public let error: (any Error)?

    /// 下载进度 0.0 ~ 1.0
    public var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    /// 是否全部完成
    public var isFinished: Bool { completed == total }
    public var hasFailed:  Bool { error != nil }
}

/// 设备存储空间信息
public struct SunDeviceStorage: Sendable {

    /// 总容量（字节）
    public let totalBytes: Int64

    /// 可用容量（字节）
    public let availableBytes: Int64

    /// 已用容量（字节）
    public var usedBytes: Int64 { totalBytes - availableBytes }

    /// 已用比例 0.0 ~ 1.0
    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    /// 格式化总容量
    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    /// 格式化可用容量
    public var formattedAvailable: String {
        ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
    }

    /// 格式化已用容量
    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }
}

/// 文件排序方式
public enum SunSortOrder: Sendable {
    case nameAscending
    case nameDescending
    case dateAscending
    case dateDescending
    case sizeAscending
    case sizeDescending
}
