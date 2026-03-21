// SunEventMulticast.swift
// SunCapture — 多路广播（delegate → 多个 AsyncStream）

import Foundation

/// 将「单次生产」fan-out 到多个 `AsyncStream` 订阅端。
///
/// **为什么要这个类型**：ImageCaptureCore 的 delegate 只有一条回调链，但业务层往往需要
/// - 用户 `for await` 监听
/// - 内部会话状态机「等确认点」
///
/// 若共用一个 `AsyncStream`，多消费者会互相抢事件；工业实现里必须用广播模型隔离关注点。
public final class SunEventMulticast<Event: Sendable>: @unchecked Sendable {

    private struct Entry {
        let id: UUID
        var continuation: AsyncStream<Event>.Continuation
    }

    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var entries: [Entry] = []
    }

    private let storage = Storage()

    public init() {}

    /// 新订阅者：与其它订阅者独立，按 yield 顺序收到同序事件。
    public func subscribe(bufferingPolicy: AsyncStream<Event>.Continuation.BufferingPolicy = .unbounded) -> AsyncStream<Event> {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            let id = UUID()
            storage.lock.lock()
            storage.entries.append(Entry(id: id, continuation: continuation))
            storage.lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.removeSubscriber(id: id)
            }
        }
    }

    /// 向所有仍存活的订阅者广播（线程安全；可在任意队列调用）。
    public func broadcast(_ event: Event) {
        storage.lock.lock()
        let snapshot = storage.entries
        storage.lock.unlock()
        for e in snapshot {
            _ = e.continuation.yield(event)
        }
    }

    private func removeSubscriber(id: UUID) {
        storage.lock.lock()
        storage.entries.removeAll { $0.id == id }
        storage.lock.unlock()
    }
}
