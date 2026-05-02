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

        // 用 nonisolated(unsafe) 持有 helper，防止 ARC 在回调前释放
        return try await withCheckedThrowingContinuation { cont in
            let options: [ICDownloadOption: Any] = [
                .downloadsDirectoryURL: directory,
                .saveAsFilename: file.name ?? UUID().uuidString,
                .overwrite: true
            ]

            // 创建 helper，通过闭包自持有
            nonisolated(unsafe) var helper: SunDownloadHelper?
            helper = SunDownloadHelper(file: file, dir: directory, cont: cont) {
                helper = nil  // 回调完成后释放自身
            }

            print("📥 开始下载: \(file.name ?? "?"), 大小: \(file.fileSize) bytes")

            device.requestDownloadFile(
                file,
                options: options,
                downloadDelegate: helper!,
                didDownloadSelector: #selector(SunDownloadHelper.done(_:error:contextInfo:)),
                contextInfo: nil
            )
        }
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
}
