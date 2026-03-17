//
//  SunCameraServiceDownload.swift
//  SunCapture — 下载相关
//
//  Created by Yanjun Sun on 2026/3/11.
//

import Foundation
import ImageCaptureCore

extension SunCameraService {

    // MARK: - 单文件下载

    /// 下载文件到临时目录，返回本地 URL
    public func downloadToTemp(_ file: ICCameraFile,
                               device: ICCameraDevice) async throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        return try await download(file, device: device, to: dir)
    }

    /// 下载文件到指定目录，返回本地 URL
    public func download(_ file: ICCameraFile,
                         device: ICCameraDevice,
                         to directory: URL) async throws -> URL {

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw SunCaptureError.directoryCreationFailed(directory, error)
        }

        return try await withCheckedThrowingContinuation { cont in
            let options: [ICDownloadOption: Any] = [
                .downloadsDirectoryURL : directory,
                .saveAsFilename        : file.name ?? UUID().uuidString,
                .overwrite             : true
            ]
            let helper = SunDownloadHelper(file: file, dir: directory, cont: cont)
            device.requestDownloadFile(
                file,
                options             : options,
                downloadDelegate    : helper,
                didDownloadSelector : #selector(SunDownloadHelper.done(_:error:contextInfo:)),
                contextInfo         : nil
            )
        }
    }

    // MARK: - 批量下载（带进度）

    /// 批量下载，通过 AsyncStream 持续回报进度
    ///
    /// 使用示例：
    /// ```swift
    /// for await progress in await service.downloadAll(files, device: device, to: folder) {
    ///     print("\(progress.completed)/\(progress.total)")
    ///     if progress.isFinished { print("全部完成") }
    /// }
    /// ```
    // SunCameraService+Download.swift
    public func downloadAll(_ files: [ICCameraFile],
                            device: ICCameraDevice,
                            to directory: URL) -> AsyncStream<SunDownloadProgress> {

        // 提前把需要的信息取出来，避免跨 actor 传递 ICCameraFile 数组
        let fileCount = files.count
        nonisolated(unsafe) let fileCopies = files  // ICCameraFile 是 @unchecked Sendable，显式捕获

        return AsyncStream { continuation in
            Task {
                for (index, file) in fileCopies.enumerated() {

                    continuation.yield(SunDownloadProgress(
                        total:           fileCount,
                        completed:       index,
                        currentFileName: file.name ?? "",
                        error:           nil
                    ))

                    // 显式处理错误，不用 try?
                    do {
                        _ = try await download(file, device: device, to: directory)
                    } catch {
                        // 单个文件失败不中断整体，继续下载剩余文件
                        continuation.yield(SunDownloadProgress(
                            total:           fileCount,
                            completed:       index,
                            currentFileName: file.name ?? "",
                            error:           error
                        ))
                    }
                }

                continuation.yield(SunDownloadProgress(
                    total:           fileCount,
                    completed:       fileCount,
                    currentFileName: "",
                    error:           nil
                ))
                continuation.finish()
            }
        }
    }
}

