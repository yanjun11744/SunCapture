// SunPhotoMetadata.swift
// SunCapture — 照片元数据模型

import Foundation

/// 照片 EXIF 元数据
public struct SunPhotoMetadata: Sendable {

    // MARK: - 拍摄参数

    /// 光圈值，如 2.8
    public let fNumber: Double?

    /// 快门速度（秒），如 0.001
    public let exposureTime: Double?

    /// ISO 感光度，如 400
    public let iso: Int?

    /// 焦距（mm），如 50.0
    public let focalLength: Double?

    /// 等效焦距（mm），如 75
    public let focalLengthIn35mm: Int?

    /// 曝光补偿，如 -0.3
    public let exposureBias: Double?

    // MARK: - 设备信息

    /// 镜头型号
    public let lensModel: String?

    /// 相机品牌
    public let make: String?

    /// 相机型号
    public let model: String?

    /// 拍摄时间
    public let dateTime: String?

    // MARK: - 格式化输出

    /// 光圈，如 "f/2.8"
    public var formattedFNumber: String? {
        guard let f = fNumber else { return nil }
        return String(format: "f/%.1f", f)
    }

    /// 快门速度，如 "1/1000s"
    public var formattedExposureTime: String? {
        guard let t = exposureTime else { return nil }
        if t >= 1 {
            return String(format: "%.1fs", t)
        } else {
            let denominator = Int(round(1.0 / t))
            return "1/\(denominator)s"
        }
    }

    /// ISO，如 "ISO 400"
    public var formattedISO: String? {
        guard let iso else { return nil }
        return "ISO \(iso)"
    }

    /// 焦距，如 "50mm"
    public var formattedFocalLength: String? {
        guard let f = focalLength else { return nil }
        return String(format: "%.0fmm", f)
    }

    /// 等效焦距，如 "75mm"
    public var formattedFocalLengthIn35mm: String? {
        guard let f = focalLengthIn35mm else { return nil }
        return "\(f)mm"
    }

    /// 曝光补偿，如 "+0.3 EV"
    public var formattedExposureBias: String? {
        guard let b = exposureBias, b != 0 else { return nil }
        return String(format: "%+.1f EV", b)
    }

    // MARK: - 从原始字典解析

    public init(from raw: [AnyHashable: Any]) {
        let exif = raw["{Exif}"] as? [AnyHashable: Any]
        let tiff = raw["{TIFF}"] as? [AnyHashable: Any]

        fNumber        = exif?["FNumber"] as? Double
        exposureTime   = exif?["ExposureTime"] as? Double
        iso            = (exif?["ISOSpeedRatings"] as? [Int])?.first
        focalLength    = exif?["FocalLength"] as? Double
        focalLengthIn35mm = exif?["FocalLenIn35mmFilm"] as? Int
        exposureBias   = exif?["ExposureBiasValue"] as? Double
        lensModel      = exif?["LensModel"] as? String
        make           = tiff?["Make"] as? String
        model          = tiff?["Model"] as? String
        dateTime       = tiff?["DateTime"] as? String
    }
}

extension SunPhotoMetadata: CustomStringConvertible {

    public var description: String {
        var parts: [String] = []

        if let f = formattedFNumber { parts.append(f) }
        if let e = formattedExposureTime { parts.append(e) }
        if let iso = formattedISO { parts.append(iso) }
        if let f = formattedFocalLength { parts.append(f) }
        if let eq = formattedFocalLengthIn35mm { parts.append("35mm: \(eq)") }
        if let ev = formattedExposureBias { parts.append(ev) }
        if let lens = lensModel { parts.append(lens) }
        if let make = make { parts.append(make) }
        if let model = model { parts.append(model) }
        if let date = dateTime { parts.append(date) }

        return parts.joined(separator: " | ")
    }
}