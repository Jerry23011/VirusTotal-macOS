//
//  FileAnalysis.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import Foundation
import Alamofire
import Defaults

final class FileAnalysisCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [UUID: Request] = [:]
    private var isCancelled = false

    func register(_ request: Request) -> UUID {
        lock.lock()
        defer { lock.unlock() }

        let id = UUID()
        if isCancelled {
            request.cancel()
        } else {
            requests[id] = request
        }
        return id
    }

    func unregister(_ id: UUID) {
        lock.lock()
        requests.removeValue(forKey: id)
        lock.unlock()
    }

    func cancelAll() {
        lock.lock()
        isCancelled = true
        let activeRequests = Array(requests.values)
        requests.removeAll()
        lock.unlock()

        activeRequests.forEach { $0.cancel() }
    }
}

private final class FileAnalysisRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var request: Request?
    private var isCancelled = false

    func set(_ request: Request) {
        lock.lock()
        if isCancelled {
            lock.unlock()
            request.cancel()
        } else {
            self.request = request
            lock.unlock()
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let request = request
        self.request = nil
        lock.unlock()

        request?.cancel()
    }
}

private final class FileAnalysisRequestRegistrationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var id: UUID?

    func set(_ id: UUID?) {
        lock.lock()
        self.id = id
        lock.unlock()
    }

    func unregister(from cancellationToken: FileAnalysisCancellationToken?) {
        lock.lock()
        let id = id
        self.id = nil
        lock.unlock()

        if let id {
            cancellationToken?.unregister(id)
        }
    }
}

actor FileAnalysis {
    static let shared = FileAnalysis()

    /// Ask VirusTotal how far along the queued analysis is.
    /// Returns the raw `status` string, or nil when the response carries none.
    func getAnalysisStatus(analysisId: String,
                           cancellationToken: FileAnalysisCancellationToken? = nil) async throws -> String? {
        let apiEndPoint = "https://www.virustotal.com/api/v3/analyses/\(analysisId)"
        let headers: HTTPHeaders = [
            "accept": "application/json",
            "x-apikey": apiKey
        ]
        let requestBox = FileAnalysisRequestBox()
        let registrationBox = FileAnalysisRequestRegistrationBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let request = AF.request(apiEndPoint, method: .get, headers: headers)
                    .validate()
                    .responseDecodable(of: AnalysisStatusResponse.self) { response in
                        defer { registrationBox.unregister(from: cancellationToken) }

                        if response.error?.isExplicitlyCancelledError == true {
                            continuation.resume(throwing: CancellationError())
                            return
                        }

                        switch response.result {
                        case .success(let status):
                            continuation.resume(returning: status.data.attributes.status)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                registrationBox.set(cancellationToken?.register(request))
                requestBox.set(request)
            }
        } onCancel: {
            requestBox.cancel()
        }
    }

    func getFileReport(sha256: String, cancellationToken: FileAnalysisCancellationToken? = nil) async throws -> FileAnalysisResult {
        let apiEndPoint = "https://www.virustotal.com/api/v3/files/\(sha256)"
        let headers: HTTPHeaders = [
            "accept": "application/json",
            "x-apikey": apiKey
        ]
        let requestBox = FileAnalysisRequestBox()
        let registrationBox = FileAnalysisRequestRegistrationBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let request = AF.request(apiEndPoint, method: .get, headers: headers)
                    .validate()
                    .responseDecodable(of: FileAnalysisResponse.self) { response in
                        defer { registrationBox.unregister(from: cancellationToken) }

                        if response.error?.isExplicitlyCancelledError == true {
                            continuation.resume(throwing: CancellationError())
                            return
                        }

                        continuation.resume(returning: self.makeFileAnalysisResult(from: response))
                    }
                registrationBox.set(cancellationToken?.register(request))
                requestBox.set(request)
            }
        } onCancel: {
            requestBox.cancel()
        }
    }

    func uploadFile(fileURL: URL,
                    apiEndPoint: String,
                    cancellationToken: FileAnalysisCancellationToken? = nil,
                    progressHandler: @Sendable @escaping (Double) -> Void) async throws -> FileUploadResult {
        let headers: HTTPHeaders = [
            "accept": "application/json",
            "content-type": "multipart/form-data",
            "x-apikey": apiKey
        ]
        let requestBox = FileAnalysisRequestBox()
        let registrationBox = FileAnalysisRequestRegistrationBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let request = AF.upload(
                    multipartFormData: { multipartFormData in
                        self.appendFile(to: multipartFormData, from: fileURL)
                    },
                    to: apiEndPoint,
                    headers: headers)
                .validate()
                .uploadProgress { progress in
                    progressHandler(progress.fractionCompleted)
                }
                .responseDecodable(of: FileUploadResponse.self) { response in
                    defer { registrationBox.unregister(from: cancellationToken) }

                    if response.error?.isExplicitlyCancelledError == true {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    var fileUploadResult = FileUploadResult(statusMonitor: nil,
                                                            errorMessage: nil,
                                                            uploadSuccess: nil,
                                                            analysisId: nil)

                    switch response.result {
                    case .success(let uploadResponse):
                        fileUploadResult.uploadSuccess = true
                        fileUploadResult.analysisId = uploadResponse.data.id
                        continuation.resume(returning: fileUploadResult)
                    case .failure(let error):
                        log.error(error)
                        fileUploadResult.uploadSuccess = false
                        fileUploadResult.errorMessage = error.displayMessageWithCode
                        fileUploadResult.statusMonitor = .fail
                        continuation.resume(returning: fileUploadResult)
                    }
                }
                registrationBox.set(cancellationToken?.register(request))
                requestBox.set(request)
            }
        } onCancel: {
            requestBox.cancel()
        }
    }

    func getLargeFileEndpoint(cancellationToken: FileAnalysisCancellationToken? = nil) async throws -> FileGetEndpointResult {
        let apiEndPoint = "https://www.virustotal.com/api/v3/files/upload_url"
        let headers: HTTPHeaders = [
            "x-apikey": apiKey
        ]
        let requestBox = FileAnalysisRequestBox()
        let registrationBox = FileAnalysisRequestRegistrationBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let request = AF.request(apiEndPoint, method: .get, headers: headers)
                    .validate()
                    .responseDecodable(of: FileGetEndpointResponse.self) { response in
                        defer { registrationBox.unregister(from: cancellationToken) }

                        if response.error?.isExplicitlyCancelledError == true {
                            continuation.resume(throwing: CancellationError())
                            return
                        }

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
                            endpointResult.errorMessage = error.displayMessageWithCode
                            endpointResult.statusMonitor = .fail
                            continuation.resume(returning: endpointResult)
                        }
                    }
                registrationBox.set(cancellationToken?.register(request))
                requestBox.set(request)
            }
        } onCancel: {
            requestBox.cancel()
        }
    }

    func reanalyzeFile(sha256: String, cancellationToken: FileAnalysisCancellationToken? = nil) async throws {
        let apiEndPoint = "https://www.virustotal.com/api/v3/files/\(sha256)/analyse"
        let headers: HTTPHeaders = [
            "x-apikey": apiKey
        ]
        let requestBox = FileAnalysisRequestBox()
        let registrationBox = FileAnalysisRequestRegistrationBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let request = AF.request(apiEndPoint,
                                         method: .post,
                                         headers: headers)
                    .validate()
                    .response { response in
                        defer { registrationBox.unregister(from: cancellationToken) }

                        if response.error?.isExplicitlyCancelledError == true {
                            continuation.resume(throwing: CancellationError())
                            return
                        }

                        switch response.result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            log.error(error)
                            continuation.resume(throwing: error)
                        }
                    }
                registrationBox.set(cancellationToken?.register(request))
                requestBox.set(request)
            }
        } onCancel: {
            requestBox.cancel()
        }
    }

    // MARK: Private

    private var apiKey: String { Defaults[.apiKey] }

    nonisolated private func makeFileAnalysisResult(from response: DataResponse<FileAnalysisResponse, AFError>) -> FileAnalysisResult {
        var result = FileAnalysisResult(getReportSuccess: nil,
                                        statusMonitor: .analyzing,
                                        errorMessage: nil,
                                        lastAnalysisStats: nil,
                                        typeDescription: nil,
                                        lastAnalysisDate: nil,
                                        reputation: nil,
                                        uniqueSources: nil)

        switch response.result {
        case .success(let analyses):
            let attributes = analyses.data.attributes
            result.lastAnalysisStats = attributes.lastAnalysisStats
            result.lastAnalysisDate = attributes.lastAnalysisDate?.unixTimestampToDate()
            result.reputation = attributes.reputation
            result.typeDescription = attributes.typeDescription
            result.uniqueSources = attributes.uniqueSources
            result.getReportSuccess = true
        case .failure(let error):
            if response.response?.statusCode == 404 {
                result.statusMonitor = .upload
            } else {
                log.error(error)
                result.errorMessage = error.displayMessageWithCode
                result.statusMonitor = .fail
            }
        }

        return result
    }

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
    /// Identifier of the analysis VirusTotal queued for this upload.
    var analysisId: String?
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

/// Minimal shape of `/analyses/{id}` — only the status is needed here.
struct AnalysisStatusResponse: Decodable {
    let data: AnalysisStatusData
}

struct AnalysisStatusData: Decodable {
    let attributes: AnalysisStatusAttributes
}

struct AnalysisStatusAttributes: Decodable {
    let status: String?
}

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
