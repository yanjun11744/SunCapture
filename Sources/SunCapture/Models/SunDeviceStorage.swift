//
//  SunDeviceStorage.swift
//  SunCapture
//
//  Created by Yanjun Sun on 2026/3/16.
//

import Foundation

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
