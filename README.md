# SunCapture

一个基于 **Swift Concurrency** 的 macOS 相机设备管理库，封装 ImageCaptureCore，提供干净的 `AsyncStream` 事件流接口。

## 特性

- ✅ `AsyncStream` 事件驱动，告别 delegate 回调乱象
- ✅ `actor` 保证并发安全
- ✅ `async/await` 文件下载
- ✅ 通用 `SunAsyncBridge`，可桥接任意 delegate → AsyncStream
- ✅ 分层架构（Driver / Service），易于测试和扩展

## 架构

```
SunCameraService  (业务层 actor)
      │
      ▼
SunCameraDriver   (驱动层，封装 ImageCaptureCore delegate)
      │
  AsyncStream<SunDeviceEvent>
      │
      ▼
ImageCaptureCore
```

## 安装

在 `Package.swift` 中添加：

```swift
.package(url: "https://github.com/yourname/SunCapture", from: "1.0.0")
```

## 快速开始

### 监听设备和文件事件

```swift
import SunCapture

let service = SunCameraService()

Task {
    for await event in await service.events {
        switch event {
        case .deviceAdded(let cam):
            print("相机连接:", cam.name ?? "")
            await service.open(cam)

        case .deviceReady(let cam):
            print("目录加载完毕:", cam.name ?? "")

        case .fileAdded(let file):
            print("新文件:", file.name ?? "")

        case .thumbnailReady(let file, let image):
            // image 是 CGImage，可直接用于 SwiftUI / AppKit
            break

        case .error(let err):
            print("错误:", err.localizedDescription)

        default:
            break
        }
    }
}
```

### 下载文件

```swift
let url = try await service.download(file, device: device, to: destinationFolder)
print("已下载到:", url.path)
```

### 删除文件

```swift
await service.delete([file1, file2], from: device)
```

### 自定义 AsyncStream 桥接（通用工具）

SunCapture 提供 `SunAsyncBridge`，可用于任意 delegate → AsyncStream 场景：

```swift
enum MyEvent { case connected, disconnected }

final class MyDriver: NSObject {
    let bridge = SunAsyncBridge<MyEvent>()
    var events: AsyncStream<MyEvent> { bridge.stream }
}

// 在 delegate 里
bridge.yield(.connected)

// 在 async 上下文消费
for await event in driver.events {
    print(event)
}
```

## 事件类型 `SunDeviceEvent`

| 事件 | 说明 |
|------|------|
| `.deviceAdded(cam)` | 新相机连接 |
| `.deviceRemoved(cam)` | 相机断开 |
| `.sessionOpened(cam)` | 会话打开成功 |
| `.sessionClosed(cam)` | 会话关闭 |
| `.deviceReady(cam)` | 文件目录枚举完毕 |
| `.fileAdded(file)` | 新文件出现 |
| `.fileRemoved(file)` | 文件移除 |
| `.fileRenamed(file)` | 文件重命名 |
| `.thumbnailReady(file, image)` | 缩略图就绪（CGImage）|
| `.metadataReady(file, metadata)` | 元数据就绪 |
| `.accessRestricted(device)` | 相机启用访问限制 |
| `.accessUnrestricted(device)` | 访问限制解除 |
| `.error(SunCaptureError)` | 错误 |

## 要求

- macOS 14+
- Swift 5.9+
- Xcode 15+

## License

MIT
