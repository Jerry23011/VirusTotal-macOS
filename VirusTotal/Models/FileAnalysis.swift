//
//  FileAnalysis.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import Foundation
import Alamofire
import Defaults

actor FileAnalysis {
    static let shared = FileAnalysis()

    func getFileReport(sha256: String) async throws -> FileAnalysisResult {
        let apiEndPoint = "https://www.virustotal.com/api/v3/files/\(sha256)"
        let headers: HTTPHeaders = [
            "accept": "application/json",
            "x-apikey": apiKey
        ]

        return try await withCheckedThrowingContinuation { continuation in
            currentAFRequest = AF.request(apiEndPoint, method: .get, headers: headers)
                .validate()
                .responseDecodable(of: FileAnalysisResponse.self) { [weak self] response in
                    guard self != nil else { return }

                    var fileAlysResult = FileAnalysisResult(getReportSuccess: nil,
                                                            statusMonitor: .analyzing,
                                                            errorMessage: nil,
                                                            lastAnalysisStats: nil,
                                                            typeDescription: nil,
                                                            lastAnalysisDate: nil,
                                                            reputation: nil,
                                                            uniqueSources: nil)

                    switch response.result {
                    case .success(let analyses):
                        let alysAttrs = analyses.data.attributes
                        fileAlysResult.lastAnalysisStats = alysAttrs.lastAnalysisStats
                        fileAlysResult.lastAnalysisDate = alysAttrs.lastAnalysisDate?.unixTimestampToDate()
                        fileAlysResult.reputation = alysAttrs.reputation
                        fileAlysResult.typeDescription = alysAttrs.typeDescription
                        fileAlysResult.uniqueSources = alysAttrs.uniqueSources
                        fileAlysResult.getReportSuccess = true
                        continuation.resume(returning: fileAlysResult)
                    case .failure(let error):
                        if response.response?.statusCode == 404 {
                            fileAlysResult.statusMonitor = .upload
                        } else {
                            log.error(error)
                            fileAlysResult.errorMessage = error.localizedDescription
                            fileAlysResult.statusMonitor = .fail
                        }
                        continuation.resume(returning: fileAlysResult)
                    }
                }
        }
    }

    func uploadFile(fileURL: URL,
                    apiEndPoint: String,
                    progressHandler: @Sendable @escaping (Double) -> Void) async throws -> FileUploadResult {
        let headers: HTTPHeaders = [
            "accept": "application/json",
            "content-type": "multipart/form-data",
            "x-apikey": apiKey
        ]

        return try await withCheckedThrowingContinuation { continuation in
            currentAFRequest = AF.upload(
                multipartFormData: { multipartFormData in
                    self.appendFile(to: multipartFormData, from: fileURL)
                },
                to: apiEndPoint,
                headers: headers)
            .validate()
            .uploadProgress { progress in
                progressHandler(progress.fractionCompleted)
            }
            .responseDecodable(of: FileUploadResponse.self) { [weak self] response in
                guard self != nil else { return }

                var fileUploadResult = FileUploadResult(statusMonitor: nil,
                                                        errorMessage: nil,
                                                        uploadSuccess: nil)

                switch response.result {
                case .success:
                    fileUploadResult.uploadSuccess = true
                    continuation.resume(returning: fileUploadResult)
                case .failure(let error):
                    log.error(error)
                    fileUploadResult.uploadSuccess = false
                    fileUploadResult.errorMessage = error.localizedDescription
                    fileUploadResult.statusMonitor = .fail
                    continuation.resume(returning: fileUploadResult)
                }
            }
        }
    }

    func getLargeFileEndpoint() async throws -> FileGetEndpointResult {
        let apiEndPoint = "https://www.virustotal.com/api/v3/files/upload_url"
        let headers: HTTPHeaders = [
            "x-apikey": apiKey
        ]

        return try await withCheckedThrowingContinuation { continuation in
            currentAFRequest = AF.request(apiEndPoint, method: .get, headers: headers)
                .validate()
                .responseDecodable(of: FileGetEndpointResponse.self) { response in

                    var endpointResult = FileGetEndpointResult(statusMonitor: nil,
                                                               errorMessage: nil,
                                                               getEndpointSuccess: nil,
                                                               largeFileEndpoint: nil)

                    switch response.result {
                    case .success(let endpointResponse):
                        endpointResult.getEndpointSuccess = true
                        endpointResult.largeFileEndpoint = endpointResponse.data
                        continuation.resume(returning: endpointResult)
                    case .failure(let error):
                        log.error(error)
                        endpointResult.getEndpointSuccess = false
                        endpointResult.errorMessage = error.localizedDescription
                        endpointResult.statusMonitor = .fail
                        continuation.resume(returning: endpointResult)
                    }
                }
        }
    }

    func reanalyzeFile(sha256: String) async throws {
        let apiEndPoint = "https://www.virustotal.com/api/v3/files/\(sha256)/analyse"
        let headers: HTTPHeaders = [
            "x-apikey": apiKey
        ]

        return try await withCheckedThrowingContinuation { continuation in
            currentAFRequest = AF.request(apiEndPoint,
                                          method: .post,
                                          headers: headers)
                .validate()
                .response { response in
                    switch response.result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        log.error(error)
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

    /// Cancle the on-going AF request
    func cancelAFRequest() {
        currentAFRequest?.cancel()
        currentAFRequest = nil
    }

    // MARK: Private

    /// Store a reference to the current request
    private var currentAFRequest: Request?
    private var apiKey: String { Defaults[.apiKey] }

    /// Appends a file to the given MultipartFormData instance.
    /// Handle AF's .bodyPartFilenameInvalid error for files without an extension e.g. Mach-O
    private func appendFile(to multipartFormData: MultipartFormData, from fileURL: URL) {
        let fileName = fileURL.lastPathComponent
        let pathExtension = fileURL.pathExtension
        if !fileName.isEmpty && !pathExtension.isEmpty {
            multipartFormData.append(fileURL, withName: "file")
        } else {
            let defaultFileName = "file"
            let defaultMimeType = "application/octet-stream"
            multipartFormData.append(fileURL,
                                     withName: "file",
                                     fileName: defaultFileName,
                                     mimeType: defaultMimeType)
        }
    }
}

// MARK: Results

struct FileAnalysisResult {
    var getReportSuccess: Bool?
    var statusMonitor: AnalysisStatus?
    var errorMessage: String?
    var lastAnalysisStats: FileAnalysisStats?
    var typeDescription: String?
    var lastAnalysisDate: String?
    var reputation: Int?
    var uniqueSources: Int?
}

struct FileUploadResult {
    var statusMonitor: AnalysisStatus?
    var errorMessage: String?
    var uploadSuccess: Bool?
}

struct FileGetEndpointResult {
    var statusMonitor: AnalysisStatus?
    var errorMessage: String?
    var getEndpointSuccess: Bool?
    var largeFileEndpoint: String?
}

// MARK: File Analysis Response

struct FileAnalysisResponse: Decodable {
    let data: FileAnalysisData

    private enum CodingKeys: String, CodingKey {
        case data
    }
}

struct FileAnalysisData: Codable {
    let type: String
    let id: String
    let attributes: FileAnalysisAttributes
}

struct FileAnalysisAttributes: Codable {
    let lastAnalysisStats: FileAnalysisStats
    let lastAnalysisDate: Double? // Not in json response during analysis
    let reputation: Int
    let typeDescription: String
    let uniqueSources: Int?

    private enum CodingKeys: String, CodingKey {
        case lastAnalysisStats = "last_analysis_stats"
        case lastAnalysisDate = "last_analysis_date"
        case reputation = "reputation"
        case typeDescription = "type_description"
        case uniqueSources = "unique_sources"
    }
}

struct FileAnalysisStats: Codable {
    let malicious: Int
    let suspicious: Int
    let undetected: Int
    let harmless: Int
    let timeout: Int
    let confirmedTimeout: Int
    let failure: Int
    let typeUnsupported: Int

    private enum CodingKeys: String, CodingKey {
        case malicious = "malicious"
        case suspicious = "suspicious"
        case undetected = "undetected"
        case harmless = "harmless"
        case timeout = "timeout"
        case confirmedTimeout = "confirmed-timeout"
        case failure = "failure"
        case typeUnsupported = "type-unsupported"
    }
}

// MARK: File Upload Response

struct FileUploadResponse: Decodable {
    let data: UploadResponse

    private enum CodingKeys: String, CodingKey {
        case data
    }
}

struct UploadResponse: Codable {
    let type: String
    let id: String
    let links: UploadLink
}

struct UploadLink: Codable {
    let `self`: String
}

struct FileGetEndpointResponse: Decodable {
    var data: String
}
