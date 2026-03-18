# SunCapture

A lightweight Swift wrapper around ImageCaptureCore for accessing photos from cameras and iOS devices on macOS.

## ✨ Features

* 📷 Detect connected cameras and iPhones
* 🗂 Browse photo files
* 🖼 Load thumbnails
* 📊 Fetch metadata (optional)
* ⚡ Reactive event stream design

---

## 📦 Requirements

* macOS 13+
* Swift 5.9+

> ⚠️ Not available on iOS / iPadOS

---

## 🚀 Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/yourname/SunCapture.git", from: "1.0.0")
```

---

## 🧩 Usage

### 1. Start browsing devices

```swift
let capture = SunCapture()

capture.start()
```

---

### 2. Listen to events

```swift
capture.onEvent { event in
    switch event {
    case .deviceAdded(let device):
        print("Device connected:", device.name)

    case .filesLoaded(let files):
        print("Loaded files:", files.count)

    case .thumbnailReady(let file, let image):
        print("Thumbnail ready")

    case .metadataReady(let file, let metadata):
        print("Metadata:", metadata)

    default:
        break
    }
}
```

---

### 3. Load files

```swift
capture.loadFiles(for: device)
```

---

### 4. Load thumbnails

```swift
capture.requestThumbnail(for: file)
```

---

### 5. Load metadata (optional)

```swift
capture.requestMetadata(for: file)
```

> ⚠️ Metadata is not guaranteed for all devices.

---

## 🔐 Device Lock Behavior

When connecting an iPhone:

* Locked → Access denied
* Unlocked → Access granted

You should wait for:

```swift
cameraDeviceDidBecomeReady
```

before requesting contents.

---

## 🧪 Testing

Hardware-dependent features cannot be reliably tested in unit tests.

Recommended approach:

* Use protocol abstraction
* Inject mock devices

---

## 🛠 Architecture

```
SunCapture
 ├── Driver     (ICCameraDevice wrapper)
 ├── Service    (business logic)
 ├── Stream     (event system)
 ├── Models     (data structures)
```

---

## ⚠️ Limitations

* macOS only
* No background access
* Metadata availability varies by device

---

## 📄 License

MIT
