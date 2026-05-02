//
//  SunCameraServiceDownload.swift
//  SunCapture — 下载相关
//

import Foundation
import ImageCaptureCore

extension SunCameraService {

    // MARK: - 单文件下载

    public func downloadToTemp(_ file: ICCameraFile,
                               device: ICCameraDevice) async throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        return try await download(file, device: device, to: dir)
    }

    public func download(_ file: ICCameraFile,
                         device: ICCameraDevice,
                         to directory: URL) async throws -> URL {

        try await ensureCatalogReady(device: device)

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw SunCaptureError.directoryCreationFailed(directory, error)
        }

        let fileName = file.name ?? UUID().uuidString

        // ✅ 优先走直接拷贝（绕开 ImageCaptureCore UInt32 文件大小限制，修复 -9934）
        if let sourceURL = file.url {
            print("📥 直接拷贝模式: \(fileName), url: \(sourceURL.path)")
            return try await copyFileDirect(from: sourceURL,
                                            to: directory,
                                            fileName: fileName)
        }

        // ⬇️ 降级：PTP 设备没有挂载路径，走 requestDownloadFile
        print("📥 ICC下载模式: \(fileName), 大小: \(file.fileSize) bytes")
        return try await downloadViaICC(file: file, device: device,
                                        directory: directory, fileName: fileName)
    }

    // MARK: - 批量下载（带进度）

    public func downloadAll(_ files: [ICCameraFile],
                            device: ICCameraDevice,
                            to directory: URL) -> AsyncStream<SunDownloadProgress> {

        let fileCount = files.count
        nonisolated(unsafe) let fileCopies = files

        return AsyncStream { continuation in
            Task {
                for (index, file) in fileCopies.enumerated() {

                    continuation.yield(SunDownloadProgress(
                        total: fileCount,
                        completed: index,
                        currentFileName: file.name ?? "",
                        error: nil
                    ))

                    do {
                        _ = try await download(file, device: device, to: directory)
                        print("✅ 下载完成: \(file.name ?? "?")")
                    } catch {
                        print("❌ 下载失败: \(file.name ?? "?"), 错误: \(error)")
                        continuation.yield(SunDownloadProgress(
                            total: fileCount,
                            completed: index,
                            currentFileName: file.name ?? "",
                            error: error
                        ))
                    }
                }

                continuation.yield(SunDownloadProgress(
                    total: fileCount,
                    completed: fileCount,
                    currentFileName: "",
                    error: nil
                ))
                continuation.finish()
            }
        }
    }

    // MARK: - 直接文件系统拷贝（支持 > 4GB，绕开 ICC -9934）

    private func copyFileDirect(from source: URL,
                                to directory: URL,
                                fileName: String) async throws -> URL {
        let destination = directory.appendingPathComponent(fileName)

        return try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default

            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }

            try fm.copyItem(at: source, to: destination)

            let size = (try? fm.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? -1
            print("✅ 拷贝完成: \(fileName), 大小: \(size) bytes")

            return destination
        }.value
    }

    // MARK: - ICC requestDownloadFile 降级路径（< 4GB PTP 设备）

    private func downloadViaICC(file: ICCameraFile,
                                device: ICCameraDevice,
                                directory: URL,
                                fileName: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { cont in
            let options: [ICDownloadOption: Any] = [
                .downloadsDirectoryURL: directory,
                .saveAsFilename: fileName,
                .overwrite: true
            ]
            nonisolated(unsafe) var helper: SunDownloadHelper?
            helper = SunDownloadHelper(file: file, dir: directory, cont: cont) {
                helper = nil
            }
            device.requestDownloadFile(
                file,
                options: options,
                downloadDelegate: helper!,
                didDownloadSelector: #selector(SunDownloadHelper.done(_:error:contextInfo:)),
                contextInfo: nil
            )
        }
    }
}