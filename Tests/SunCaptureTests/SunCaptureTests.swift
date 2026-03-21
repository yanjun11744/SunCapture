// SunAsyncBridgeTests.swift
import Testing
@testable import SunCapture

// MARK: - SunAsyncBridge 测试

@Suite("SunAsyncBridge")
struct SunAsyncBridgeTests {

    // 基础：yield 的数据能被消费到
    @Test("yield 的值可以被 for await 接收")
    func yieldAndConsume() async {
        let bridge = SunAsyncBridge<Int>()

        bridge.yield(1)
        bridge.yield(2)
        bridge.yield(3)
        bridge.finish()

        var results: [Int] = []
        for await value in bridge.stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }

    // finish 之后 stream 立即结束
    @Test("finish 后 stream 不再产生数据")
    func finishStopsStream() async {
        let bridge = SunAsyncBridge<String>()
        bridge.finish()

        var count = 0
        for await _ in bridge.stream {
            count += 1
        }

        #expect(count == 0)
    }

    // 枚举事件类型
    @Test("枚举类型事件正常传递")
    func enumEvents() async {
        enum TestEvent { case a, b, c }
        let bridge = SunAsyncBridge<TestEvent>()

        bridge.yield(.a)
        bridge.yield(.b)
        bridge.yield(.c)
        bridge.finish()

        var events: [TestEvent] = []
        for await e in bridge.stream {
            events.append(e)
        }

        #expect(events.count == 3)
    }

    // yield 返回值
    @Test("yield 返回 enqueued 状态")
    func yieldResult() {
        let bridge = SunAsyncBridge<Int>()
        let result = bridge.yield(42)

        // unbounded 策略下永远是 enqueued
        if case .enqueued = result {
            #expect(Bool(true))
        } else {
            Issue.record("yield 应该返回 .enqueued")
        }

        bridge.finish()
    }

    // 顺序保证
    @Test("事件顺序与 yield 顺序一致", arguments: [10, 50, 100])
    func preservesOrder(count: Int) async {
        let bridge = SunAsyncBridge<Int>()

        for i in 0..<count { bridge.yield(i) }
        bridge.finish()

        var received: [Int] = []
        for await v in bridge.stream { received.append(v) }

        #expect(received == Array(0..<count))
    }
}

// MARK: - SunThrowingBridge 测试

@Suite("SunThrowingBridge")
struct SunThrowingBridgeTests {

    struct TestError: Error, Equatable {
        let code: Int
    }

    // 正常事件传递
    @Test("正常事件可以被消费")
    func normalEvents() async throws {
        let bridge = SunThrowingBridge<String>()

        bridge.yield("hello")
        bridge.yield("world")
        bridge.finish()

        var results: [String] = []
        for try await value in bridge.stream {
            results.append(value)
        }

        #expect(results == ["hello", "world"])
    }

    // 错误传播
    @Test("finish(throwing:) 会让 for try await 抛出错误")
    func throwsError() async {
        let bridge = SunThrowingBridge<Int>()

        bridge.yield(1)
        bridge.finish(throwing: TestError(code: 404))

        var caught: TestError?
        do {
            for try await _ in bridge.stream {}
        } catch let e as TestError {
            caught = e
        } catch {
            Issue.record("捕获了错误类型不符：\(error)")
        }

        #expect(caught == TestError(code: 404))
    }

    // finish 无错误
    @Test("finish() 无错误时 stream 正常结束")
    func finishWithoutError() async throws {
        let bridge = SunThrowingBridge<Int>()
        bridge.finish()

        var count = 0
        for try await _ in bridge.stream { count += 1 }

        #expect(count == 0)
    }
}

// MARK: - SunCaptureError 测试

@Suite("SunCaptureError")
struct SunCaptureErrorTests {

    @Test("noDevice 错误描述不为空")
    func noDeviceDescription() {
        let error = SunCaptureError.noDevice
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("sessionFailed 包含原始错误信息")
    func sessionFailedDescription() {
        struct Inner: LocalizedError {
            var errorDescription: String? { "连接超时" }
        }
        let error = SunCaptureError.sessionFailed(Inner())
        #expect(error.errorDescription?.contains("连接超时") == true)
    }

    @Test("operationTimedOut 描述包含操作名")
    func operationTimedOutDescription() {
        let error = SunCaptureError.operationTimedOut(operation: "openSession")
        #expect(error.errorDescription?.contains("openSession") == true)
    }

    @Test("deviceDisconnected 描述包含 uuid")
    func deviceDisconnectedDescription() {
        let error = SunCaptureError.deviceDisconnected(uuid: "test-uuid")
        #expect(error.errorDescription?.contains("test-uuid") == true)
    }
}
