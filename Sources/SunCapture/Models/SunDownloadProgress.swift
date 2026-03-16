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
