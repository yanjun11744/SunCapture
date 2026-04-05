// MARK: - 完整字段补全版本

import Foundation

/// 照片 EXIF 元数据（完整版）
public struct SunPhotoMetadata: Sendable {

    // MARK: - 图像尺寸（来自根字典，非 EXIF/TIFF 子字典）

    /// 像素宽度（根字典）
    public let pixelXDimension: Int?

    /// 像素高度（根字典）
    public let pixelYDimension: Int?

    /// 图像方向（1=正常，3=旋转180°，6=顺时针90°，8=逆时针90°）
    public let orientation: Int?

    // MARK: - 拍摄参数（来自 {Exif}）

    /// 光圈值，如 3.5
    public let fNumber: Double?

    /// 快门速度（秒），如 0.01666…
    public let exposureTime: Double?

    /// ISO 感光度列表中的第一个值，如 3200
    public let iso: Int?

    /// 焦距（mm），如 16.0
    public let focalLength: Double?

    /// 等效35mm焦距（mm），如 24
    public let focalLengthIn35mm: Int?

    /// 曝光补偿（EV），如 0.0
    public let exposureBias: Double?

    /// 曝光模式（0=自动，1=手动，2=自动包围）
    public let exposureMode: Int?

    /// 曝光程序（0=未定义，1=手动，2=正常，3=光圈优先，4=快门优先…）
    public let exposureProgram: Int?

    /// 测光模式（0=未知，1=点测光，3=点测光，5=矩阵/评价测光…）
    public let meteringMode: Int?

    /// 白平衡（0=自动，1=手动）
    public let whiteBalance: Int?

    /// 闪光灯状态（0=未闪，1=闪光）
    public let flash: Int?

    /// 增益控制（0=无，1=低增益，2=高增益…）
    public let gainControl: Int?

    /// 对比度（0=正常，1=低，2=高）
    public let contrast: Int?

    /// 饱和度（0=正常，1=低，2=高）
    public let saturation: Int?

    /// 锐度（0=正常，1=低，2=高）
    public let sharpness: Int?

    /// 场景捕获类型（0=标准，1=风景，2=人像，3=夜景）
    public let sceneCaptureType: Int?

    /// 光源类型（0=未知，1=日光，2=荧光灯…）
    public let lightSource: Int?

    /// 自定义渲染（0=正常，1=自定义/如相机内置滤镜）
    public let customRendered: Int?

    /// 推荐曝光指数（与 ISO 相关的建议值）
    public let recommendedExposureIndex: Int?

    /// 感光度类型（1=SOS，2=REI，3=ISO 速度，…）
    public let sensitivityType: Int?

    // MARK: - 镜头信息（来自 {Exif}）

    /// 镜头品牌，如 "NIKON"
    public let lensMake: String?

    /// 镜头型号，如 "NIKKOR Z DX 16-50mm f/3.5-6.3 VR"
    public let lensModel: String?

    /// 镜头序列号
    public let lensSerialNumber: String?

    /// 镜头规格：[最短焦距, 最长焦距, 最大光圈, 最小光圈]
    public let lensSpecification: [String]?

    // MARK: - 相机设备信息（来自 {TIFF}）

    /// 相机品牌，如 "NIKON CORPORATION"
    public let make: String?

    /// 相机型号，如 "NIKON Z 30"
    public let model: String?

    /// 固件/软件版本，如 "Ver.01.20"
    public let software: String?

    /// 压缩方式（34713 = Nikon 专用 NEF 压缩）
    public let compression: Int?

    /// 光度解释（32803 = CFA 拜尔阵列，用于 RAW）
    public let photometricInterpretation: Int?

    // MARK: - 时间信息

    /// 文件修改时间（来自 {TIFF} DateTime）
    public let dateTime: Date?

    /// 原始拍摄时间（来自 {Exif} DateTimeOriginal）
    public let dateTimeOriginal: Date?

    /// 数字化时间（来自 {Exif} DateTimeDigitized，通常与 Original 相同）
    public let dateTimeDigitized: Date?

    /// 亚秒时间戳（来自 SubsecTimeOriginal，精度补充）
    public let subsecTimeOriginal: String?

    // MARK: - 图像尺寸（来自 {TIFF}）

    /// TIFF 像素宽度
    public let pixelWidth: Int?

    /// TIFF 像素高度
    public let pixelHeight: Int?

    // MARK: - 传感器信息（来自 {Exif}）

    /// CFA（拜尔）图案（0=红,1=绿,2=蓝；如 [0,1,1,2] = RGGB）
    public let cfaPattern: [Int]?

    /// 文件来源（3=数码相机）
    public let fileSource: Int?

    /// 场景类型（1=直接拍摄）
    public let sceneType: Int?

    /// 感测方法（2=单芯片色彩感测）
    public let sensingMethod: Int?

    // MARK: - 机身信息（来自 {Exif}）

    /// 机身序列号
    public let bodySerialNumber: String?

    // MARK: - 初始化

    public init(from raw: [AnyHashable: Any]) {
        let exif = raw[Key.exif] as? [AnyHashable: Any]
        let tiff = raw[Key.tiff] as? [AnyHashable: Any]

        // 根字典
        pixelXDimension             = raw[Key.pixelXDimension] as? Int
        pixelYDimension             = raw[Key.pixelYDimension] as? Int
        orientation                 = raw[Key.orientation] as? Int

        // EXIF - 拍摄参数
        fNumber                     = exif?[Key.fNumber] as? Double
        exposureTime                = exif?[Key.exposureTime] as? Double
        iso                         = (exif?[Key.iso] as? [Int])?.first
        focalLength                 = exif?[Key.focalLength] as? Double
        focalLengthIn35mm           = exif?[Key.focalLength35] as? Int
        exposureBias                = exif?[Key.exposureBias] as? Double
        exposureMode                = exif?[Key.exposureMode] as? Int
        exposureProgram             = exif?[Key.exposureProgram] as? Int
        meteringMode                = exif?[Key.meteringMode] as? Int
        whiteBalance                = exif?[Key.whiteBalance] as? Int
        flash                       = exif?[Key.flash] as? Int
        gainControl                 = exif?[Key.gainControl] as? Int
        contrast                    = exif?[Key.contrast] as? Int
        saturation                  = exif?[Key.saturation] as? Int
        sharpness                   = exif?[Key.sharpness] as? Int
        sceneCaptureType            = exif?[Key.sceneCaptureType] as? Int
        lightSource                 = exif?[Key.lightSource] as? Int
        customRendered              = exif?[Key.customRendered] as? Int
        recommendedExposureIndex    = exif?[Key.recommendedExposureIndex] as? Int
        sensitivityType             = exif?[Key.sensitivityType] as? Int

        // EXIF - 镜头
        lensMake                    = exif?[Key.lensMake] as? String
        lensModel                   = exif?[Key.lensModel] as? String
        lensSerialNumber            = exif?[Key.lensSerialNumber] as? String
        lensSpecification           = (exif?[Key.lensSpecification] as? [Any])?.map { "\($0)" }

        // TIFF - 设备
        make                        = tiff?[Key.make] as? String
        model                       = tiff?[Key.model] as? String
        software                    = tiff?[Key.software] as? String
        compression                 = tiff?[Key.compression] as? Int
        photometricInterpretation   = tiff?[Key.photometricInterpretation] as? Int
        pixelWidth                  = tiff?[Key.pixelWidth] as? Int
        pixelHeight                 = tiff?[Key.pixelHeight] as? Int

        // 时间
        dateTime                    = Self.parseDate(tiff?[Key.dateTime] as? String)
        dateTimeOriginal            = Self.parseDate(exif?[Key.dateTimeOriginal] as? String)
        dateTimeDigitized           = Self.parseDate(exif?[Key.dateTimeDigitized] as? String)
        subsecTimeOriginal          = exif?[Key.subsecTimeOriginal] as? String

        // 传感器
        cfaPattern                  = exif?[Key.cfaPattern] as? [Int]
        fileSource                  = exif?[Key.fileSource] as? Int
        sceneType                   = exif?[Key.sceneType] as? Int
        sensingMethod               = exif?[Key.sensingMethod] as? Int

        // 机身
        bodySerialNumber            = exif?[Key.bodySerialNumber] as? String
    }
}

// MARK: - Keys
private enum Key {
    static let exif                     = "{Exif}"
    static let tiff                     = "{TIFF}"

    // 根字典
    static let pixelXDimension          = "PixelXDimension"
    static let pixelYDimension          = "PixelYDimension"
    static let orientation              = "Orientation"

    // EXIF 拍摄参数
    static let fNumber                  = "FNumber"
    static let exposureTime             = "ExposureTime"
    static let iso                      = "ISOSpeedRatings"
    static let focalLength              = "FocalLength"
    static let focalLength35            = "FocalLenIn35mmFilm"
    static let exposureBias             = "ExposureBiasValue"
    static let exposureMode             = "ExposureMode"
    static let exposureProgram          = "ExposureProgram"
    static let meteringMode             = "MeteringMode"
    static let whiteBalance             = "WhiteBalance"
    static let flash                    = "Flash"
    static let gainControl              = "GainControl"
    static let contrast                 = "Contrast"
    static let saturation               = "Saturation"
    static let sharpness                = "Sharpness"
    static let sceneCaptureType         = "SceneCaptureType"
    static let lightSource              = "LightSource"
    static let customRendered           = "CustomRendered"
    static let recommendedExposureIndex = "RecommendedExposureIndex"
    static let sensitivityType          = "SensitivityType"

    // EXIF 镜头
    static let lensMake                 = "LensMake"
    static let lensModel                = "LensModel"
    static let lensSerialNumber         = "LensSerialNumber"
    static let lensSpecification        = "LensSpecification"

    // TIFF
    static let make                     = "Make"
    static let model                    = "Model"
    static let software                 = "Software"
    static let compression              = "Compression"
    static let photometricInterpretation = "PhotometricInterpretation"
    static let pixelWidth               = "PixelWidth"
    static let pixelHeight              = "PixelHeight"

    // 时间
    static let dateTime                 = "DateTime"
    static let dateTimeOriginal         = "DateTimeOriginal"
    static let dateTimeDigitized        = "DateTimeDigitized"
    static let subsecTimeOriginal       = "SubsecTimeOriginal"

    // 传感器
    static let cfaPattern               = "CFAPattern"
    static let fileSource               = "FileSource"
    static let sceneType                = "SceneType"
    static let sensingMethod            = "SensingMethod"

    // 机身
    static let bodySerialNumber         = "BodySerialNumber"
}

// MARK: - 格式化输出
public extension SunPhotoMetadata {

    /// 光圈，如 "f/3.5"
    var formattedFNumber: String? {
        guard let f = fNumber else { return nil }
        return "f/" + f.formatted(.number.precision(.fractionLength(1)))
    }

    /// 快门速度，如 "1/60s"
    var formattedExposureTime: String? {
        guard let t = exposureTime else { return nil }
        if t >= 1 { return t.formatted(.number.precision(.fractionLength(1))) + "s" }
        let denominator = max(1, Int(round(1.0 / t)))
        return "1/\(denominator)s"
    }

    /// ISO，如 "ISO 3200"
    var formattedISO: String? {
        guard let iso else { return nil }
        return "ISO \(iso)"
    }

    /// 焦距，如 "16mm"
    var formattedFocalLength: String? {
        guard let f = focalLength else { return nil }
        return f.formatted(.number.precision(.fractionLength(0))) + "mm"
    }

    /// 等效焦距，如 "24mm"
    var formattedFocalLengthIn35mm: String? {
        guard let f = focalLengthIn35mm else { return nil }
        return "\(f)mm"
    }

    /// 曝光补偿，如 "+0.3 EV"（为 0 时返回 nil）
    var formattedExposureBias: String? {
        guard let b = exposureBias, b != 0 else { return nil }
        return b.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always())) + " EV"
    }

    /// 拍摄时间，如 "Apr 2, 2026 at 9:02:59 PM"
    var formattedDate: String? {
        (dateTimeOriginal ?? dateTime)?.formatted(date: .abbreviated, time: .standard)
    }

    /// 曝光程序文字描述
    var exposureProgramDescription: String? {
        switch exposureProgram {
        case 0: return "未定义"
        case 1: return "手动"
        case 2: return "正常自动"
        case 3: return "光圈优先"
        case 4: return "快门优先"
        case 5: return "创意（景深优先）"
        case 6: return "动作（高速优先）"
        case 7: return "人像"
        case 8: return "风景"
        default: return nil
        }
    }

    /// 测光模式文字描述
    var meteringModeDescription: String? {
        switch meteringMode {
        case 0: return "未知"
        case 1: return "平均测光"
        case 2: return "中央重点测光"
        case 3: return "点测光"
        case 4: return "多点测光"
        case 5: return "矩阵/评价测光"
        case 6: return "局部测光"
        default: return nil
        }
    }

    /// 白平衡文字描述
    var whiteBalanceDescription: String? {
        switch whiteBalance {
        case 0: return "自动"
        case 1: return "手动"
        default: return nil
        }
    }
}

// MARK: - CustomStringConvertible
extension SunPhotoMetadata: CustomStringConvertible {

    public var description: String {
        [
            formattedFNumber,
            formattedExposureTime,
            formattedISO,
            formattedFocalLength,
            focalLengthIn35mm.map { "35mm: \($0)mm" },
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

    static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }
}
