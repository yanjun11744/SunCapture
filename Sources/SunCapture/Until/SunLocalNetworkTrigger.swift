// SunLocalNetworkTrigger.swift
// SunCapture — 本地网络权限触发器

import Foundation
import Network

/// 触发 macOS 本地网络权限弹窗，并在发现 PTP 设备后通知 `SunCameraService` 重启扫描。
///
/// ## 使用方式
/// 在 App UI 就绪后（`.task` 修饰符内）调用一次：
/// ```swift
/// .task {
///     await SunLocalNetworkTrigger.shared.activate(service: store.service)
/// }
/// ```
public actor SunLocalNetworkTrigger {

    public static let shared = SunLocalNetworkTrigger()

    private var browser: NWBrowser?
    private var activated = false

    private init() {}

    public func activate(service: SunCameraService) async {
        guard !activated else { return }
        activated = true

        // 提前创建 browser，在 actor 上下文内直接赋值
        let params = NWParameters()
        params.includePeerToPeer = true
        let b = NWBrowser(for: .bonjour(type: "_ptp._tcp", domain: "local."), using: params)
        browser = b  // 在 actor 隔离内直接赋值，不需要跨边界

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            nonisolated(unsafe) var resumed = false

            b.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard !resumed else { return }
                    resumed = true
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        await service.restartBrowsing()
                        cont.resume()
                    }
                case .failed:
                    guard !resumed else { return }
                    resumed = true
                    cont.resume()
                default:
                    break
                }
            }

            b.start(queue: .main)
        }
    }
}
