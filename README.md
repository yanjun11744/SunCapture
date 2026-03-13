# SunCapture

**SunCapture** 是一个基于 Swift Concurrency 的 macOS 相机管理库，封装了 Apple 的 `ImageCaptureCore` 框架，提供简洁的 `async/await` + `AsyncStream` 接口，让相机文件管理变得轻松。

---

## 目录

- [架构](#架构)
- [快速开始](#快速开始)
- [核心模块](#核心模块)
  - [SunCameraService](#suncameraservice)
  - [SunCameraDriver](#suncameradriver)
  - [SunAsyncBridge](#sunasyncbridge)
  - [SunDeviceEvent](#sundeviceevent)
  - [SunCaptureError](#suncaptureerror)
- [文件过滤与排序](#文件过滤与排序)
- [文件下载](#文件下载)
- [存储与重复检测](#存储与重复检测)
- [ICCameraFile 扩展](#iccamerafile-扩展)
- [进度与排序模型](#进度与排序模型)
- [系统要求](#系统要求)

---

## 架构

```
SunCameraService  (业务层 actor)
      │
      ▼
SunCameraDriver   (驱动层，封装 ImageCaptureCore delegate)
      │
      ▼
ImageCaptureCore  (Apple 系统框架)
```

- **SunCameraService** — 业务层 `actor`，提供设备管理、文件过滤、下载、存储分析等高层 API
- **SunCameraDriver** — 驱动层，封装 `ICDeviceBrowser` / `ICCameraDevice` delegate，将所有事件转为 `AsyncStream`
- **SunAsyncBridge** — 通用 delegate → `AsyncStream` 桥接工具，可独立复用

---

## 快速开始

```swift
import SunCapture

let service = SunCameraService()

Task {
    for await event in await service.events {
        switch event {
        case .deviceAdded(let cam):
            await service.open(cam)

        case .deviceReady(let cam):
            let photos = await service.photos(from: cam)
            print("照片数量：", photos.count)

        case .fileAdded(let file):
            print("新文件：", file.name ?? "")

        case .thumbnailReady(let file, let image):
            // 在 UI 上显示缩略图
            break

        case .error(let err):
            print("错误：", err.localizedDescription)

        default:
            break
        }
    }
}
```

---

## 核心模块

### SunCameraService

`public actor SunCameraService`

业务层入口，初始化后自动开始扫描设备。

#### 设备管理

```swift
let service = SunCameraService()

// 打开相机会话（在收到 .deviceAdded 后调用）
await service.open(device)

// 关闭相机会话
await service.close(device)
```

#### 事件流

```swift
// 订阅所有设备 / 文件事件
for await event in await service.events { ... }
```

---

### SunCameraDriver

`public final class SunCameraDriver`

底层驱动，通常不需要直接使用，由 `SunCameraService` 内部持有。如需自定义业务层，可直接操作 Driver：

```swift
let driver = SunCameraDriver()
driver.startBrowsing()

for await event in driver.events {
    switch event {
    case .deviceAdded(let cam):
        driver.openSession(cam)
    case .fileAdded(let file):
        driver.requestThumbnail(for: file)
    default:
        break
    }
}
```

**主要方法：**

| 方法 | 说明 |
|---|---|
| `startBrowsing()` | 开始扫描连接的相机设备 |
| `stopBrowsing()` | 停止扫描 |
| `openSession(_:)` | 打开设备会话，开始枚举文件 |
| `closeSession(_:)` | 关闭设备会话 |
| `deleteFiles(_:from:)` | 删除文件 |
| `requestThumbnail(for:)` | 请求缩略图 |
| `requestMetadata(for:)` | 请求元数据 |

---

### SunAsyncBridge

`public final class SunAsyncBridge<Event: Sendable>`

通用 delegate → `AsyncStream` 桥接工具，可独立用于任何需要将 delegate 回调转为异步流的场景。

```swift
let bridge = SunAsyncBridge<MyEvent>()

// 在 delegate 回调里推送事件
bridge.yield(.something)

// 在任意 async 上下文消费
for await event in bridge.stream {
    handle(event)
}

// 结束流
bridge.finish()
```

**初始化参数：**

```swift
// 默认无限缓冲，也可指定策略
let bridge = SunAsyncBridge<MyEvent>(bufferingPolicy: .bufferingNewest(10))
```

对于需要抛出错误的场景，可使用 `SunThrowingBridge<Event>`，接口与 `SunAsyncBridge` 相同，但 `finish` 支持传入错误：

```swift
let bridge = SunThrowingBridge<MyEvent>()
bridge.finish(throwing: someError)
```

---

### SunDeviceEvent

所有设备与文件事件通过此枚举传递：

```swift
public enum SunDeviceEvent: @unchecked Sendable {
    // 设备生命周期
    case deviceAdded(ICCameraDevice)
    case deviceRemoved(ICCameraDevice)

    // 会话
    case sessionOpened(ICCameraDevice)
    case sessionClosed(ICCameraDevice)
    case deviceReady(ICCameraDevice)      // 文件目录加载完毕

    // 文件
    case fileAdded(ICCameraFile)
    case fileRemoved(ICCameraFile)
    case fileRenamed(ICCameraFile)

    // 媒体数据
    case thumbnailReady(file: ICCameraFile, image: CGImage)
    case metadataReady(file: ICCameraFile, metadata: [AnyHashable: Any])

    // 访问限制
    case accessRestricted(ICDevice)
    case accessUnrestricted(ICDevice)

    // 错误
    case error(SunCaptureError)
}
```

**典型事件顺序：**

```
.deviceAdded → [调用 open()] → .sessionOpened → .fileAdded (每个文件) → .deviceReady
```

---

### SunCaptureError

`public enum SunCaptureError: LocalizedError`

| case | 说明 |
|---|---|
| `.noDevice` | 没有已连接的相机 |
| `.sessionFailed(Error)` | 会话打开 / 关闭失败 |
| `.downloadFailed(ICCameraFile, Error)` | 文件下载失败 |
| `.thumbnailFailed(ICCameraFile, Error)` | 缩略图获取失败 |
| `.directoryCreationFailed(URL, Error)` | 下载目录创建失败 |

---

## 文件过滤与排序

`SunCameraService` 扩展提供丰富的文件过滤与排序 API：

```swift
// 获取所有文件
let all = await service.allFiles(from: device)

// 按类型过滤
let photos  = await service.photos(from: device)    // JPEG / RAW / HEIC / PNG / TIFF
let videos  = await service.videos(from: device)
let raws    = await service.rawFiles(from: device)
let jpegs   = await service.jpegs(from: device)

// 按品牌过滤
let canonFiles = await service.files(from: device, brand: "Canon")
let sonyFiles  = await service.files(from: device, brand: "Sony")

// 按日期过滤
let today  = await service.todayFiles(from: device)
let range  = await service.files(from: device, between: startDate, and: endDate)

// 排序
let sorted = await service.sorted(photos, by: .dateDescending)
```

**可用排序方式 (`SunSortOrder`)：**

| 枚举值 | 说明 | `shortLabel` | `label` |
|---|---|---|---|
| `.nameAscending` | 名称 A→Z | `名称 A→Z` | `名称：A → Z` |
| `.nameDescending` | 名称 Z→A | `名称 Z→A` | `名称：Z → A` |
| `.dateDescending` | 最新优先 | `日期 最新` | `日期：最新优先` |
| `.dateAscending` | 最旧优先 | `日期 最旧` | `日期：最旧优先` |
| `.sizeDescending` | 从大到小 | `大小 最大` | `大小：从大到小` |
| `.sizeAscending` | 从小到大 | `大小 最小` | `大小：从小到大` |

---

## 文件下载

### 单文件下载

```swift
// 下载到临时目录
let url = try await service.downloadToTemp(file, device: device)

// 下载到指定目录
let url = try await service.download(file, device: device, to: destinationFolder)
```

### 批量下载（带进度）

```swift
for await progress in await service.downloadAll(files, device: device, to: folder) {
    print("\(progress.completed)/\(progress.total) — \(progress.currentFileName)")
    print("进度：\(Int(progress.fraction * 100))%")

    if let error = progress.error {
        print("文件失败：", error.localizedDescription)
        // 单个文件失败不会中断整体下载
    }

    if progress.isFinished {
        print("全部完成")
    }
}
```

**`SunDownloadProgress` 属性：**

| 属性 | 类型 | 说明 |
|---|---|---|
| `total` | `Int` | 总文件数 |
| `completed` | `Int` | 已完成数量 |
| `currentFileName` | `String` | 当前正在下载的文件名 |
| `error` | `Error?` | `nil` 表示成功 |
| `fraction` | `Double` | 进度 0.0 ~ 1.0 |
| `isFinished` | `Bool` | 是否全部完成 |
| `hasFailed` | `Bool` | 当前条目是否失败 |

---

## 存储与重复检测

```swift
// 设备存储空间
if let storage = await service.storage(of: device) {
    print("总容量：", storage.formattedTotal)
    print("可用：",   storage.formattedAvailable)
    print("已用：",   storage.formattedUsed)
    print("使用率：", String(format: "%.1f%%", storage.usedFraction * 100))
}

// 计算文件总大小
let totalSize = await service.totalSize(of: files)
let formatted = await service.formattedTotalSize(of: files)

// 重复文件检测（按文件名匹配本地目录）
let duplicates = await service.duplicates(in: files, localDirectory: localFolder)
let newOnly    = await service.newFiles(in: files, localDirectory: localFolder)

// 检查单个文件是否已存在
let exists = await service.exists(file, in: localFolder)
```

---

## ICCameraFile 扩展

`ICCameraFile` 通过 `extension ICCameraFile` 获得以下便利属性：

### 文件类型

```swift
file.isPhoto    // JPEG / RAW / HEIC / PNG / TIFF
file.isJPEG
file.isPNG
file.isTIFF
file.isHEIC
file.isRAW      // 所有品牌 RAW 格式
file.isVideo
file.isAudio
```

### 相机品牌

```swift
file.isCanon      // cr2, cr3, crw
file.isNikon      // nef, nrw
file.isSony       // arw, srf, sr2
file.isFujifilm   // raf
file.isOlympus    // orf, ori
file.isPanasonic  // rw2, raw
file.isDNG        // dng (Adobe)
// ... 更多品牌

// 根据扩展名推测品牌字符串
file.cameraBrand  // Optional<String>，如 "Canon"、"Sony"
```

**支持的 RAW 格式：**

Canon (cr2/cr3/crw)、Nikon (nef/nrw)、Sony (arw/srf/sr2)、Fujifilm (raf)、Olympus (orf/ori)、Panasonic/Leica (rw2/raw)、Pentax (pef/ptx)、Samsung (srw)、Sigma (x3f)、Hasselblad (3fr/fff)、Phase One (iiq/cap)、Leica (rwl)、Adobe DNG、Kodak (dcr/kdc)、Minolta (mrw)、Epson (erf)、Mamiya (mef)、GoPro (gpr)

### 格式化信息

```swift
file.formattedSize           // "12.3 MB"
file.formattedDate           // "2026年3月11日 14:30"
file.fileExtension           // "cr3"（小写，不含点）
file.nameWithoutExtension    // "DSC_1053"
```

---

## 进度与排序模型

### SunDeviceStorage

```swift
public struct SunDeviceStorage: Sendable {
    var totalBytes: Int64
    var availableBytes: Int64
    var usedBytes: Int64          // 计算属性
    var usedFraction: Double      // 0.0 ~ 1.0
    var formattedTotal: String
    var formattedAvailable: String
    var formattedUsed: String
}
```

### SunSortOrder

```swift
public enum SunSortOrder: Sendable {
    case nameAscending, nameDescending
    case dateAscending, dateDescending
    case sizeAscending, sizeDescending
}

// 扩展属性
order.label        // 完整标签，适合菜单
order.shortLabel   // 短标签，适合按钮
order.systemImage  // SF Symbol 名称
order.isAscending  // Bool
```

---

## 系统要求

| 项目 | 要求 |
|---|---|
| **平台** | macOS 13.0+ |
| **语言** | Swift 5.9+ |
| **框架依赖** | `ImageCaptureCore`、`AppKit`、`Foundation` |
| **并发模型** | Swift Concurrency（async/await、Actor、AsyncStream） |

> ⚠️ `ImageCaptureCore` 仅在 macOS 上可用，不支持 iOS / tvOS / watchOS。

---

## License

MIT