//
//  SunPhotoMetadata.swift
//  SunCapture — 照片元数据模型
//

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

    /// 拍摄时间（已解析为 Date）
    public let dateTime: Date?

    // MARK: - 初始化

    /// 从 ImageCapture / EXIF 原始字典解析
    public init(from raw: [AnyHashable: Any]) {

        let exif = raw[Key.exif] as? [AnyHashable: Any]
        let tiff = raw[Key.tiff] as? [AnyHashable: Any]

        fNumber            = exif?[Key.fNumber] as? Double
        exposureTime       = exif?[Key.exposureTime] as? Double
        iso                = (exif?[Key.iso] as? [Int])?.first
        focalLength        = exif?[Key.focalLength] as? Double
        focalLengthIn35mm  = exif?[Key.focalLength35] as? Int
        exposureBias       = exif?[Key.exposureBias] as? Double

        lensModel          = exif?[Key.lensModel] as? String
        make               = tiff?[Key.make] as? String
        model              = tiff?[Key.model] as? String

        dateTime           = Self.parseDate(tiff?[Key.dateTime] as? String)
    }
}

// MARK: - Key（避免魔法字符串）
private enum Key {

    static let exif = "{Exif}"
    static let tiff = "{TIFF}"

    static let fNumber = "FNumber"
    static let exposureTime = "ExposureTime"
    static let iso = "ISOSpeedRatings"
    static let focalLength = "FocalLength"
    static let focalLength35 = "FocalLenIn35mmFilm"
    static let exposureBias = "ExposureBiasValue"
    static let lensModel = "LensModel"

    static let make = "Make"
    static let model = "Model"
    static let dateTime = "DateTime"
}

// MARK: - 格式化输出
public extension SunPhotoMetadata {

    /// 光圈，如 "f/2.8"
    var formattedFNumber: String? {
        guard let f = fNumber else { return nil }
        return "f/" + f.formatted(.number.precision(.fractionLength(1)))
    }

    /// 快门速度，如 "1/1000s"
    var formattedExposureTime: String? {
        guard let t = exposureTime else { return nil }

        if t >= 1 {
            return t.formatted(.number.precision(.fractionLength(1))) + "s"
        } else {
            let denominator = max(1, Int(round(1.0 / t)))
            return "1/\(denominator)s"
        }
    }

    /// ISO，如 "ISO 400"
    var formattedISO: String? {
        guard let iso else { return nil }
        return "ISO \(iso)"
    }

    /// 焦距，如 "50mm"
    var formattedFocalLength: String? {
        guard let f = focalLength else { return nil }
        return f.formatted(.number.precision(.fractionLength(0))) + "mm"
    }

    /// 等效焦距，如 "75mm"
    var formattedFocalLengthIn35mm: String? {
        guard let f = focalLengthIn35mm else { return nil }
        return "\(f)mm"
    }

    /// 曝光补偿，如 "+0.3 EV"
    var formattedExposureBias: String? {
        guard let b = exposureBias, b != 0 else { return nil }

        return b.formatted(
            .number
                .precision(.fractionLength(1))
                .sign(strategy: .always())
        ) + " EV"
    }

    /// 拍摄时间（格式化）
    var formattedDate: String? {
        guard let dateTime else { return nil }

        return dateTime.formatted(
            date: .abbreviated,
            time: .standard
        )
    }
}

// MARK: - 描述输出
extension SunPhotoMetadata: CustomStringConvertible {

    public var description: String {
        [
            formattedFNumber,
            formattedExposureTime,
            formattedISO,
            formattedFocalLength,
            formattedFocalLengthIn35mm.map { "35mm: \($0)" },
            formattedExposureBias,
            lensModel,
            make,
            model,
            formattedDate
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }
}

// MARK: - Private Helpers
private extension SunPhotoMetadata {

    /// 解析 EXIF 日期（yyyy:MM:dd HH:mm:ss）
    static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        return formatter.date(from: string)
    }
}
