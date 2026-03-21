//
//  Common.swift
//  SunCapture
//
//  Created by Yanjun Sun on 2026/3/21.
//
import Foundation

/// 在固定墙钟时间内完成 `operation`，先到先返回；超时抛出 ``SunCaptureError/operationTimedOut(operation:)``。
func withTimeout<T: Sendable>(
    seconds: Double,
    operationLabel: String = "operation",
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw SunCaptureError.operationTimedOut(operation: operationLabel)
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
