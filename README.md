# SunCapture

一个基于 **Swift Concurrency** 的 macOS 相机设备管理库，封装 ImageCaptureCore，提供干净的 `AsyncStream` 事件流接口。

## 特性

- ✅ `AsyncStream` 事件驱动，告别 delegate 回调乱象
- ✅ `actor` 保证并发安全
- ✅ `async/await` 单文件 & 批量下载（带进度）
- ✅ 文件过滤（照片 / 视频 / RAW / 日期范围）
- ✅ 文件排序（名称 / 日期 / 大小）
- ✅ 重复文件检测
- ✅ 存储空间查询
- ✅ `ICCameraFile` 便利扩展
- ✅ 通用 `SunAsyncBridge`，可桥接任意 delegate → AsyncStream

## 架构

```
SunCameraService          (业务层 actor)
  ├── +Download           下载相关
  ├── +Filter             过滤与排序
  └── +Storage            存储空间与重复检测
        │
        ▼
SunCameraDriver           (驱动层，封装 ImageCaptureCore delegate)
        │
    AsyncStream<SunDeviceEvent>
        │
        ▼
ImageCaptureCore
```

## 安装

### Swift Package Manager

```swift
.package(url: "https://github.com/yourname/SunCapture", from: "1.0.0")
```

或本地开发：

```swift
.package(path: "../SunCapture")
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
            await service.open(cam)

        case .deviceReady:
            print("目录加载完毕")

        case .fileAdded(let file):
            print(file.name ?? "", file.formattedSize)

        case .thumbnailReady(let file, let image):
            // CGImage 直接用于 SwiftUI / AppKit
            break

        case .error(let err):
            print(err.localizedDescription)

        default:
            break
        }
    }
}
```

### 下载文件

```swift
// 单文件
let url = try await service.download(file, device: device, to: destinationFolder)

// 批量下载带进度
for await progress in await service.downloadAll(files, device: device, to: folder) {
    print("\(progress.completed)/\(progress.total) - \(progress.currentFileName)")
    if progress.isFinished { print("全部完成") }
}
```

### 文件过滤与排序

```swift
// 只要照片
let photos = await service.photos(from: device)

// 只要视频
let videos = await service.videos(from: device)

// 只要 RAW
let raws = await service.rawFiles(from: device)

// 今天的文件
let today = await service.todayFiles(from: device)

// 按日期降序排列
let sorted = await service.sorted(photos, by: .dateDescending)
```

### 重复文件检测

```swift
// 过滤掉本地已有的文件
let newOnly = await service.newFiles(in: allFiles, localDirectory: destinationFolder)

// 检查单个文件是否已存在
let exists = await service.exists(file, in: destinationFolder)
```

### 存储空间

```swift
if let storage = await service.storage(of: device) {
    print("总容量:", storage.formattedTotal)
    print("可用:", storage.formattedAvailable)
    print("已用:", storage.formattedUsed)
    print("使用率:", storage.usedFraction)
}

// 计算选中文件总大小
let size = await service.formattedTotalSize(of: selectedFiles)
```

### ICCameraFile 便利属性

```swift
file.isPhoto              // Bool
file.isVideo              // Bool
file.isRAW                // Bool
file.isHEIC               // Bool
file.formattedSize        // "12.3 MB"
file.formattedDate        // "2024年3月11日 14:30"
file.fileExtension        // "jpg"
file.nameWithoutExtension // "DSC_1053"
```

### 自定义 AsyncStream 桥接

```swift
let bridge = SunAsyncBridge<MyEvent>()

// 在 delegate 里
bridge.yield(.connected)

// 在 async 上下文消费
for await event in bridge.stream { }
```

## 事件类型

| 事件 | 说明 |
|------|------|
| `.deviceAdded(cam)` | 新相机连接 |
| `.deviceRemoved(cam)` | 相机断开 |
| `.sessionOpened(cam)` | 会话打开 |
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
