import Foundation
import Testing
@testable import VirusTotal

@MainActor
@Suite("Single-file scan lifecycle")
struct FileViewModelTests {
    @Test("Preparing another file clears metadata from the previous result")
    func newFileResetsResult() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("new.txt")
        try Data("new file".utf8).write(to: file)
        let model = FileViewModel()
        model.reputation = 99
        model.uniqueSources = 12
        model.typeDescription = "Old type"
        model.errorMessage = "Old error"
        model.uploadProgress = 1
        await model.setupFileInfo(fileURL: file)
        #expect(model.fileName == "new.txt")
        #expect(model.inputSHA256 == (try FileHasher.sha256(for: file)))
        #expect(model.reputation == nil)
        #expect(model.uniqueSources == nil)
        #expect(model.typeDescription == nil)
        #expect(model.errorMessage == nil)
        #expect(model.uploadProgress == 0)
        model.cancelOngoingRequest()
    }

    @Test("A cancelled app import cannot overwrite the next selected file")
    func cancelledPreparationDoesNotReplaceNewFile() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let app = folder.appendingPathComponent("Old.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(count: 4 * 1024 * 1024).write(to: app.appendingPathComponent("payload"))
        let nextFile = folder.appendingPathComponent("next.txt")
        try Data("next".utf8).write(to: nextFile)
        let model = FileViewModel()
        let oldImport = Task { await model.setupFileInfo(fileURL: app) }
        await Task.yield()
        model.cancelOngoingRequest()
        await model.setupFileInfo(fileURL: nextFile)
        await oldImport.value
        #expect(model.fileName == "next.txt")
        #expect(model.inputSHA256 == (try FileHasher.sha256(for: nextFile)))
        model.cancelOngoingRequest()
    }
}
