//
//  SunCameraServiceFilter..swift
//  SunCapture — 文件过滤与排序
//
//  Created by Yanjun Sun on 2026/3/11.
//

import Foundation
import ImageCaptureCore

extension SunCameraService {

    // MARK: - 全部文件

    /// 返回设备上所有文件
    public func allFiles(from device: ICCameraDevice) -> [ICCameraFile] {
        device.contents?.compactMap { $0 as? ICCameraFile } ?? []
    }

    // MARK: - 类型过滤

    /// 只返回照片（JPEG / RAW / HEIC / PNG / TIFF）
    public func photos(from device: ICCameraDevice) -> [ICCameraFile] {
        allFiles(from: device).filter(\.isPhoto)
    }

    /// 只返回视频
    public func videos(from device: ICCameraDevice) -> [ICCameraFile] {
        allFiles(from: device).filter(\.isVideo)
    }

    /// 只返回 RAW 文件
    public func rawFiles(from device: ICCameraDevice) -> [ICCameraFile] {
        allFiles(from: device).filter(\.isRAW)
    }

    /// 只返回 JPEG
    public func jpegs(from device: ICCameraDevice) -> [ICCameraFile] {
        allFiles(from: device).filter(\.isJPEG)
    }

    // MARK: - 品牌过滤

    /// 按品牌名过滤，如 "Canon" / "Nikon" / "Sony"
    public func files(from device: ICCameraDevice, brand: String) -> [ICCameraFile] {
        allFiles(from: device).filter { $0.cameraBrand == brand }
    }

    // MARK: - 日期过滤

    /// 按日期范围过滤
    public func files(from device: ICCameraDevice,
                      between start: Date,
                      and end: Date) -> [ICCameraFile] {
        allFiles(from: device).filter {
            guard let date = $0.modificationDate else { return false }
            return date >= start && date <= end
        }
    }

    /// 今天拍摄的文件
    public func todayFiles(from device: ICCameraDevice) -> [ICCameraFile] {
        let start = Calendar.current.startOfDay(for: Date())
        return files(from: device, between: start, and: Date())
    }

    // MARK: - 排序

    /// 对文件列表排序
    public func sorted(_ files: [ICCameraFile], by order: SunSortOrder) -> [ICCameraFile] {
        switch order {
        case .nameAscending:
            return files.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .nameDescending:
            return files.sorted { ($0.name ?? "") > ($1.name ?? "") }
        case .dateAscending:
            return files.sorted {
                ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast)
            }
        case .dateDescending:
            return files.sorted {
                ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
            }
        case .sizeAscending:
            return files.sorted { $0.fileSize < $1.fileSize }
        case .sizeDescending:
            return files.sorted { $0.fileSize > $1.fileSize }
        }
    }
}

