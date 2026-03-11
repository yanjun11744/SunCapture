// ICCameraFileSun.swift
// SunCapture — ICCameraFile 便利扩展

import Foundation
import ImageCaptureCore

public extension ICCameraFile {

    // MARK: - 文件类型判断

    /// 是否是照片（含 RAW）
    var isPhoto: Bool { isJPEG || isRAW || isHEIC || isTIFF || isPNG }

    /// 是否是 JPEG
    var isJPEG: Bool {
        ["jpg", "jpeg"].contains(fileExtension)
    }

    /// 是否是 PNG
    var isPNG: Bool {
        fileExtension == "png"
    }

    /// 是否是 TIFF
    var isTIFF: Bool {
        ["tiff", "tif"].contains(fileExtension)
    }

    /// 是否是 HEIC / HEIF
    var isHEIC: Bool {
        ["heic", "heif"].contains(fileExtension)
    }

    /// 是否是 RAW 文件（所有品牌）
    var isRAW: Bool {
        Self.rawExtensions.contains(fileExtension)
    }

    /// 是否是视频
    var isVideo: Bool {
        Self.videoExtensions.contains(fileExtension)
    }

    /// 是否是音频
    var isAudio: Bool {
        ["wav", "mp3", "aac", "m4a"].contains(fileExtension)
    }

    // MARK: - 品牌判断

    var isCanon     : Bool { ["cr2","cr3","crw"].contains(fileExtension) }
    var isNikon     : Bool { ["nef","nrw"].contains(fileExtension) }
    var isSony      : Bool { ["arw","srf","sr2"].contains(fileExtension) }
    var isFujifilm  : Bool { fileExtension == "raf" }
    var isOlympus   : Bool { ["orf","ori"].contains(fileExtension) }
    var isPanasonic : Bool { ["rw2","raw"].contains(fileExtension) }
    var isPentax    : Bool { ["pef","ptx"].contains(fileExtension) }
    var isSamsung   : Bool { fileExtension == "srw" }
    var isSigma     : Bool { fileExtension == "x3f" }
    var isHasselblad: Bool { ["3fr","fff"].contains(fileExtension) }
    var isPhaseOne  : Bool { ["iiq","cap"].contains(fileExtension) }
    var isLeica     : Bool { fileExtension == "rwl" }
    var isDNG       : Bool { fileExtension == "dng" }

    /// 根据扩展名推测相机品牌
    var cameraBrand: String? {
        switch fileExtension {
        case "cr2","cr3","crw": return "Canon"
        case "nef","nrw":       return "Nikon"
        case "arw","srf","sr2": return "Sony"
        case "raf":             return "Fujifilm"
        case "orf","ori":       return "Olympus / OM System"
        case "rw2":             return "Panasonic / Leica"
        case "pef","ptx":       return "Pentax / Ricoh"
        case "srw":             return "Samsung"
        case "x3f":             return "Sigma"
        case "3fr","fff":       return "Hasselblad"
        case "iiq","cap":       return "Phase One"
        case "rwl":             return "Leica"
        case "dng":             return "DNG (Adobe)"
        case "raw":             return "Panasonic / Leica"
        case "dcr","kdc":       return "Kodak"
        case "mrw":             return "Minolta"
        case "erf":             return "Epson"
        case "mef":             return "Mamiya"
        case "gpr":             return "GoPro"
        default:                return nil
        }
    }

    // MARK: - 格式化信息

    /// 格式化文件大小，如 "12.3 MB"
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    /// 格式化修改日期
    var formattedDate: String {
        guard let date = modificationDate else { return "未知日期" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    /// 扩展名（小写，不含点），如 "jpg"
    var fileExtension: String {
        ((name ?? "") as NSString).pathExtension.lowercased()
    }

    /// 不含扩展名的文件名，如 "DSC_1053"
    var nameWithoutExtension: String {
        ((name ?? "") as NSString).deletingPathExtension
    }

    // MARK: - 静态格式表

    static let rawExtensions: Set<String> = [
        "cr2","cr3","crw",          // Canon
        "nef","nrw",                 // Nikon
        "arw","srf","sr2",          // Sony
        "raf",                       // Fujifilm
        "orf","ori",                 // Olympus
        "rw2","raw",                 // Panasonic/Leica
        "pef","ptx",                 // Pentax
        "srw",                       // Samsung
        "x3f",                       // Sigma
        "3fr","fff",                 // Hasselblad
        "iiq","cap",                 // Phase One
        "rwl",                       // Leica
        "dng",                       // Adobe DNG
        "dcr","kdc",                 // Kodak
        "mrw",                       // Minolta
        "erf",                       // Epson
        "mef",                       // Mamiya
        "gpr",                       // GoPro
    ]

    static let videoExtensions: Set<String> = [
        "mp4","mov","avi","mkv","m4v",  // 通用
        "mts","m2ts","mxf",              // Sony AVCHD/XAVC
        "crm","rmf",                     // Canon Cinema RAW
        "3gp","flv","wmv","webm",        // 其他
        "lrv","360",                     // GoPro
    ]
}
