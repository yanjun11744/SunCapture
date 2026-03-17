//
//  SunCameraServiceStorage.swift
//  SunCapture — 存储空间与重复文件检测
//
//  Created by Yanjun Sun on 2026/3/11.
//

import Foundation
import ImageCaptureCore

extension SunCameraService {

    // MARK: - 存储空间

    /// 获取设备存储空间信息
    public func storage(of device: ICCameraDevice) -> SunDeviceStorage? {
        guard
            let total     = device.userData?["capacity"]  as? Int64,
            let available = device.userData?["freeSpace"] as? Int64
        else { return nil }

        return SunDeviceStorage(totalBytes: total, availableBytes: available)
    }

    /// 计算一组文件的总大小（字节）
    public func totalSize(of files: [ICCameraFile]) -> Int64 {
        files.reduce(0) { $0 + Int64($1.fileSize) }
    }

    /// 格式化一组文件的总大小
    public func formattedTotalSize(of files: [ICCameraFile]) -> String {
        ByteCountFormatter.string(
            fromByteCount: totalSize(of: files),
            countStyle: .file
        )
    }

    // MARK: - 重复文件检测

    /// 返回本地目录里已存在的文件（按文件名匹配）
    public func duplicates(in files: [ICCameraFile],
                           localDirectory: URL) -> [ICCameraFile] {
        let localNames = existingFileNames(in: localDirectory)
        return files.filter { localNames.contains($0.name ?? "") }
    }

    /// 过滤掉本地已存在的文件，只返回新文件
    public func newFiles(in files: [ICCameraFile],
                         localDirectory: URL) -> [ICCameraFile] {
        let localNames = existingFileNames(in: localDirectory)
        return files.filter { !localNames.contains($0.name ?? "") }
    }

    /// 检查单个文件在本地是否已存在
    public func exists(_ file: ICCameraFile, in localDirectory: URL) -> Bool {
        guard let name = file.name else { return false }
        return FileManager.default.fileExists(
            atPath: localDirectory.appendingPathComponent(name).path
        )
    }

    // MARK: - 私有

    private func existingFileNames(in directory: URL) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return Set(names)
    }
}
