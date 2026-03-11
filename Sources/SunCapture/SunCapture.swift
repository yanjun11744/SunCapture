// The Swift Programming Language
// https://docs.swift.org/swift-book

// SunCapture.swift
// 公共入口 — 统一 re-export，使用方只需 import SunCapture

/// SunCapture
///
/// 一个基于 Swift Concurrency 的 macOS 相机管理库。
///
/// ## 架构分层
/// ```
/// SunCameraService  (业务层 actor)
///       │
///       ▼
/// SunCameraDriver   (驱动层，封装 ImageCaptureCore)
///       │
///       ▼
/// ImageCaptureCore  (Apple 系统框架)
/// ```
///
/// ## 快速开始
/// ```swift
/// import SunCapture
///
/// let service = SunCameraService()
///
/// Task {
///     for await event in await service.events {
///         switch event {
///         case .deviceAdded(let cam):
///             await service.open(cam)
///         case .fileAdded(let file):
///             print("新文件:", file.name ?? "")
///         case .thumbnailReady(let file, let image):
///             // 更新 UI 缩略图
///             break
///         default:
///             break
///         }
///     }
/// }
/// ```
///
/// ## 自定义 AsyncStream 桥接
/// 如果你有其他 delegate 想接入同样的流式架构：
/// ```swift
/// let bridge = SunAsyncBridge<MyEvent>()
///
/// // 在 delegate 里 yield
/// bridge.yield(.something)
///
/// // 在 async 上下文消费
/// for await event in bridge.stream { }
/// ```

@_exported import Foundation
@_exported import ImageCaptureCore

// 所有公共类型都通过各自文件的 public 声明导出，
// 此文件仅提供文档注释作为库入口。
