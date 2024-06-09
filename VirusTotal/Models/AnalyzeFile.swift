//
//  AnalyzeFile.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import Foundation
import Alamofire
import Defaults

final class AnalyzeFile {
    static let shared = AnalyzeFile()

    private var apiKey: String { Defaults[.apiKey] }

    func getFileReport(sha256: String,
                       completion: @escaping (FileAnalysisResult) -> Void) {
        let apiEndPoint = "https://www.virustotal.com/api/v3/files/\(sha256)"
        let headers: HTTPHeaders = [
            "accept": "application/json",
            "x-apikey": apiKey
        ]
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
                case.success(let analyses):
                    let alysAttrs = analyses.data.attributes
                    fileAlysResult.lastAnalysisStats = alysAttrs.lastAnalysisStats
                    fileAlysResult.lastAnalysisDate = alysAttrs.lastAnalysisDate?.unixTimestampToDate()
                    fileAlysResult.reputation = alysAttrs.reputation
                    fileAlysResult.typeDescription = alysAttrs.typeDescription
                    fileAlysResult.uniqueSources = alysAttrs.uniqueSources
                    fileAlysResult.getReportSuccess = true
                    completion(fileAlysResult)
                case .failure(let error):
                    // If statusCode is 404 it means that the file was never uploaded
                    if response.response?.statusCode == 404 {
                        fileAlysResult.statusMonitor = .upload
                    } else {
                        fileAlysResult.errorMessage = error.localizedDescription
                        fileAlysResult.statusMonitor = .fail
                    }
                    completion(fileAlysResult)
                }
            }
    }

    func uploadFile(fileURL: URL,
                    apiEndPoint: String,
                    progressHandler: @escaping (Double) -> Void,
                    completion: @escaping (FileUploadResult) -> Void) {
        let apiEndPoint = apiEndPoint
        let headers: HTTPHeaders = [
            "accept": "application/json",
            "content-type": "multipart/form-data",
            "x-apikey": apiKey
        ]

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
                completion(fileUploadResult)
            case .failure(let error):
                fileUploadResult.uploadSuccess = false
                fileUploadResult.errorMessage = error.localizedDescription
                fileUploadResult.statusMonitor = .fail
                completion(fileUploadResult)
            }
        }
    }

    func getLargeFileEndpoint(completion: @escaping (FileGetEndpointResult) -> Void) {
        let apiEndPoint = "https://www.virustotal.com/api/v3/files/upload_url"
        let headers: HTTPHeaders = [
            "x-apikey": apiKey
        ]

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
                    completion(endpointResult)
                case .failure(let error):
                    endpointResult.getEndpointSuccess = false
                    endpointResult.errorMessage = error.localizedDescription
                    endpointResult.statusMonitor = .fail
                    completion(endpointResult)
                }
            }
    }

    func reanalyzeFile(sha256: String,
                       completion: @escaping (Bool, String?) -> Void) {
        let apiEndPoint = "https://www.virustotal.com/api/v3/files/\(sha256)/analyse"
        let headers: HTTPHeaders = [
            "x-apikey": apiKey
        ]

        currentAFRequest = AF.request(apiEndPoint,
                                      method: .post,
                                      headers: headers)
            .validate()
            .response { response in
                switch response.result {
                case .success:
                    completion(true, nil)
                case .failure(let error):
                    completion(false, error.localizedDescription)
                }
            }
    }

    /// Cancle the on-going AF request
    func cancelAFRequest() {
        currentAFRequest?.cancel()
        currentAFRequest = nil
    }

    // MARK: Private

    // Store a reference to the current request
    private var currentAFRequest: Request?

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

    enum CodingKeys: String, CodingKey {
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

    enum CodingKeys: String, CodingKey {
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

    enum CodingKeys: String, CodingKey {
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

    enum CodingKeys: String, CodingKey {
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
