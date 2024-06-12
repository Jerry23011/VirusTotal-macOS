//
//  AnalyzeFileViewModel.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import Foundation
import SwiftUI
import CryptoKit
import QuickLookThumbnailing

final class AnalyzeFileViewModel: ObservableObject {
    static let shared = AnalyzeFileViewModel()

    @Published var statusMonitor: AnalysisStatus?
    @Published var errorMessage: String?
    @Published var lastAnalysisStats: FileAnalysisStats?
    @Published var typeDescription: String?
    @Published var lastAnalysisDate: String?
    @Published var reputation: Int?
    @Published var uniqueSources: Int?

    @Published var fileSize: Int64?
    @Published var fileName: String?
    @Published var thumbnailImage: NSImage?

    // Not stable due to URLSession's behaviors
    // https://github.com/Alamofire/Alamofire/issues/3813
    @Published var uploadProgress: Double = 0.0

    var inputSHA256: String = ""

    /// Handle the File Import modifier, run setupFileInfo and getFileReport
    func handleFileImport(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        setupFileInfo(fileURL: url) {
            self.getFileReport()
        }
    }

    /// Given a fileURL, setup fileSize, fileName, thumbnailImage, and fileSHA256
    func setupFileInfo(fileURL: URL, completion: @escaping () -> Void) {
        self.cancellationRequested = false
        self.fileURL = fileURL
        let fileSize = getFileSize(for: fileURL)
        guard fileSize < 681_574_400 else {
            log.error("Filesize \(fileSize) exceeded 650 MB.")
            self.errorMessage = "Local Error: VirusTotal only accepts files up to 650 MB"
            self.statusMonitor = .fail
            return
        }
        self.fileSize = fileSize
        self.fileName = getFileName(for: fileURL)
        getThumbnailImage(for: fileURL)
        if let fileSHA256 = self.getFileSHA256(for: fileURL) {
            self.inputSHA256 = fileSHA256
        }
        completion()
    }

    func getNewFileReport(completion: ((Bool) -> Void)? = nil) {
        guard !self.cancellationRequested else { return }
        self.numberOfRetries = 0 // Reset retry count when a new request is made
        getFileReport(completion: completion)
    }

    /// Given a file sha256, get the report of the file
    func getFileReport(completion: ((Bool) -> Void)? = nil) {
        guard !self.cancellationRequested else { return }
        AnalyzeFile.shared.getFileReport(sha256: inputSHA256) { result in
            DispatchQueue.main.async {
                self.statusMonitor = result.statusMonitor
                self.errorMessage = result.errorMessage
                self.lastAnalysisStats = result.lastAnalysisStats
                self.typeDescription = result.typeDescription
                self.lastAnalysisDate = result.lastAnalysisDate
                self.reputation = result.reputation
                self.uniqueSources = result.uniqueSources

                if result.getReportSuccess == true {
                    if self.isValidResponse(responses: result.lastAnalysisStats!) {
                        self.statusMonitor = .success
                        completion?(true)
                    } else {
                        self.retryFileReport(retryCount: self.numberOfRetries,
                                             completion: completion)
                    }
                } else {
                    self.errorMessage = result.errorMessage
                    completion?(false)
                }
            }
        }
    }

    /// Upload file
    func uploadFile(completion: @escaping (Bool) -> Void) {
        guard !self.cancellationRequested else { return }
        self.statusMonitor = .uploading
        AnalyzeFile.shared.uploadFile(fileURL: self.fileURL ?? defaultFileURL,
                                      apiEndPoint: chooseUploadEndpoint(),
                                      progressHandler: { [weak self] progress in
            DispatchQueue.main.async {
                self?.uploadProgress = progress
            }
        },
                                      completion: { [weak self] uploadResult in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if uploadResult.uploadSuccess == true {
                    self.statusMonitor = .analyzing
                    self.uploadSuccess = true
                    completion(true)
                } else {
                    self.errorMessage = uploadResult.errorMessage
                    self.statusMonitor = uploadResult.statusMonitor
                    completion(false)
                }
            }
        })
    }

    /// Fetch the large file upload endpoint
    func fetchLargeFileEndpoint(completion: @escaping (Bool) -> Void) {
        guard !self.cancellationRequested else { return }
        AnalyzeFile.shared.getLargeFileEndpoint { [weak self] endpointResult in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if endpointResult.getEndpointSuccess == true {
                    self.largeFileEndpoint = endpointResult.largeFileEndpoint
                    completion(true)
                } else {
                    self.errorMessage = endpointResult.errorMessage
                    self.statusMonitor = endpointResult.statusMonitor
                    completion(false)
                }
            }
        }
    }

    /// Start file upload based on file size
    func startFileUpload() {
        guard !self.cancellationRequested else { return }
        guard let fileSize = self.fileSize else {
            log.error("No File Size \(String(describing: fileSize))")
            self.errorMessage = noFileSizeError
            self.statusMonitor = .fail
            return
        }

        switch fileSize {
        case ..<33_554_432:
            self.uploadFile { [weak self] success in
                if success {
                    // Add a 20s delay to wait for VT sync data
                    DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                        self?.getNewFileReport()
                    }
                }
            }

        case 33_554_432...681_574_400:
            self.fetchLargeFileEndpoint { [weak self] success in
                if success {
                    self?.uploadFile { uploadSuccess in
                        if uploadSuccess {
                            // Add a 20s delay to wait for VT sync data
                            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                                self?.getNewFileReport()
                            }
                        }
                    }
                } else {
                    log.error("Failed to fetch large file upload endpoint.")
                    self?.errorMessage = "Failed to fetch large file upload endpoint."
                    self?.statusMonitor = .fail
                }
            }
        default:
            self.errorMessage = "Unexpected file size."
            self.statusMonitor = .fail
        }
    }

    // Request to re-analyze a file
    func requestReanalyze() {
        guard !self.cancellationRequested else { return }

        AnalyzeFile.shared.reanalyzeFile(sha256: inputSHA256) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    self?.getNewFileReport()
                    self?.errorMessage = nil
                } else {
                    log.error(errorMessage ?? "Unknown error during re-scan")
                    self?.statusMonitor = .fail
                    self?.errorMessage = errorMessage
                }
            }
        }
    }

    /// Cancel on-going AF request and stop model from running
    func cancelOngoingRequest() {
        AnalyzeFile.shared.cancelAFRequest()
        cancellationRequested = true
        }

    // MARK: Private

    private var fileURL: URL?
    private var cancellationRequested = false // Flag to track cancellation of code
    private var largeFileEndpoint: String?
    private var uploadSuccess: Bool?
    private var numberOfRetries = 0
    private let defaultFileURL = URL(string: "file://")!
    private let noFileSizeError: String = "Local Error: Can't retrieve file size"
    private let defaultUploadURL: String = "https://www.virustotal.com/api/v3/files"

    /// Given a fileURL, return the file size in bytes
    private func getFileSize(for fileURL: URL) -> Int64 {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return fileAttributes[.size] as? Int64 ?? 0
        } catch {
            log.error("Error getting file size: \(error)")
            return 0
        }
    }

    /// Given a fileURL, return the file name
    private func getFileName(for fileURL: URL) -> String {
        return fileURL.lastPathComponent
    }

    /// Given a fileURL, return the sha256 value of the given file
    private func getFileSHA256(for fileURL: URL) -> String? {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            return nil
        }
        let hash = SHA256.hash(data: fileData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Given a fileURL, generate a thumbnail icon and pass it to the viewModel
    private func getThumbnailImage(for fileURL: URL) {
        let selectedFileURL: URL = fileURL
        let size = CGSize(width: 50, height: 50)
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let request = QLThumbnailGenerator.Request(fileAt: selectedFileURL,
                                                   size: size,
                                                   scale: scale,
                                                   representationTypes: .icon)

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [self] thumbnail, error in
            guard let thumbnail = thumbnail else {
                log.error("Thumbnail Error: \(error?.localizedDescription ?? "Unknown thumbnail error")")
                return
            }
            DispatchQueue.main.async {
                self.thumbnailImage = thumbnail.thumbnailImage
            }
        }
    }

    /// Choose the upload endpoint for uploadFile() func
    private func chooseUploadEndpoint() -> String {
        let fileSize = self.fileSize ?? 0
        if fileSize <= 33_554_432 {
            return defaultUploadURL
        } else if fileSize > 33_554_432 && fileSize <= 681_574_400 {
            return largeFileEndpoint ?? defaultUploadURL
        } else {
            return "" // Files >650MB are not supported
        }
    }

    /// Given a FileAnalysisStats, return true if the sum of the flags is not 0, false otherwise
    private func isValidResponse(responses: FileAnalysisStats) -> Bool {
        return responses.allFlags.sum { $0 } != 0
    }

    /// Retry getting file report to wait for the server processing time when new file is scanned
    /// getFileReport() will be called every 10 seconds up to 28 times (300 seconds)
    private func retryFileReport(retryCount: Int,
                                 completion: ((Bool) -> Void)? = nil) {
        guard retryCount < 28 else {
            log.error("Request Timeout. \(self.errorMessage ?? "")")
            self.errorMessage = "Request timeout." + (self.errorMessage ?? "")
            self.statusMonitor = .fail
            completion?(false)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.numberOfRetries += 1
            self.getFileReport(completion: completion)
        }
    }
}
