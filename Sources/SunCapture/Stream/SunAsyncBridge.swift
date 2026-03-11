// SunAsyncBridge.swift
// SunCapture — 通用 delegate → AsyncStream 桥接器

import Foundation

/// 通用 delegate → AsyncStream 桥接工具
///
/// 使用方式：
/// ```swift
/// let bridge = SunAsyncBridge<MyEvent>()
///
/// // 在 delegate 里 push 事件
/// bridge.yield(.something)
///
/// // 在任意 async 上下文消费
/// for await event in bridge.stream {
///     handle(event)
/// }
/// ```
public final class SunAsyncBridge<Event: Sendable>: Sendable {

    // MARK: - 公共流

    /// 对外暴露的 AsyncStream，可直接 for await 消费
    public let stream: AsyncStream<Event>

    // MARK: - 私有 continuation

    // nonisolated(unsafe)：deinit / delegate（非 MainActor 上下文）会调用 yield/finish，
    // AsyncStream.Continuation 内部已做线程安全，unsafe 标注是安全的。
    nonisolated(unsafe) private let continuation: AsyncStream<Event>.Continuation

    // MARK: - Init / Deinit

    public init(bufferingPolicy: AsyncStream<Event>.Continuation.BufferingPolicy = .unbounded) {
        var captured: AsyncStream<Event>.Continuation!
        stream = AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            captured = continuation
        }
        continuation = captured
    }

    deinit {
        continuation.finish()
    }

    // MARK: - 生产端 API

    /// 向流中推送一个事件
    @discardableResult
    public func yield(_ event: Event) -> AsyncStream<Event>.Continuation.YieldResult {
        continuation.yield(event)
    }

    /// 结束流（消费端的 for-await 循环会自动退出）
    public func finish() {
        continuation.finish()
    }
}

// MARK: - 便利：把 Result<T, Error> 桥接到 AsyncThrowingStream

/// 可抛出错误的通用桥接器
public final class SunThrowingBridge<Event: Sendable>: Sendable {

    public let stream: AsyncThrowingStream<Event, Error>

    nonisolated(unsafe) private let continuation: AsyncThrowingStream<Event, Error>.Continuation

    public init() {
        var captured: AsyncThrowingStream<Event, Error>.Continuation!
        stream = AsyncThrowingStream { continuation in
            captured = continuation
        }
        continuation = captured
    }

    deinit {
        continuation.finish()
    }

    @discardableResult
    public func yield(_ event: Event) -> AsyncThrowingStream<Event, Error>.Continuation.YieldResult {
        continuation.yield(event)
    }

    public func finish(throwing error: Error? = nil) {
        continuation.finish(throwing: error)
    }
}
