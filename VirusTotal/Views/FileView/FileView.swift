//
//  FileView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import Alamofire
import UniformTypeIdentifiers
import TipKit

struct FileView: View {
    @StateObject private var viewModel = AnalyzeFileViewModel.shared

    @State private var isFileImporterPresent: Bool = false
    @State private var isFileDropped: Bool = false

    var body: some View {
        ZStack {
            VStack {
                Text("fileview.title")
                    .font(.title)
                    .frame(maxWidth: .infinity, maxHeight: 0, alignment: .leading)
                    .padding(.vertical)
                switch viewModel.statusMonitor {
                case .none:
                    Spacer()
                    VStack(alignment: .center) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 80))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.accentColor)
                        OpenFinderButton(title: "fileview.button.open.finder",
                                         systemImage: "folder",
                                         action: onPressFileImporter)
                        .frame(width: 200)
                        .padding(.top)
                        .scaleEffect(isFileDropped ? 1.05 : 1)
                        .animation(.spring, value: isFileDropped)
                        .keyboardShortcut("o", modifiers: .command)
                        .fileImporter(isPresented: $isFileImporterPresent,
                                      allowedContentTypes: [.data],
                                      allowsMultipleSelection: false) { result in
                            switch result {
                            case .success(let urls):
                                urls.forEach { url in
                                    Task {
                                        await viewModel.handleFileImport(url)
                                    }
                                }
                            case .failure(let error):
                                log.error("File Import Error: \(error.localizedDescription)")
                            }
                        }
                        Text("fileview.button.open.caption")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 60)
                case .loading:
                    LoadingView()
                case .success:
                    FileReportView()
                case .upload, .uploading:
                    Spacer()
                    FileUploadView()
                        .padding(.bottom, 60)
                case .fail:
                    ErrorView(title: "errorview.title",
                              errorMessage: viewModel.errorMessage ?? "")
                case .analyzing:
                    LoadingView()
                case .empty: // Will not be used in FileView
                    EmptyView()
                }
                Spacer()
                // Button to visit File report on VT website
                Button {
                    NSWorkspace.shared.open(URL(string: makeVtURL(from: viewModel.inputSHA256)) ?? vtWebsite)
                } label: {
                    Label("urlview.button.go.vt", systemImage: "arrowshape.turn.up.right.fill")
                        .symbolEffect(.bounce, value: isUploadFinished())
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(!isUploadFinished())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical)
            .padding(.horizontal, 20)
            .onDrop(of: [.fileURL], delegate: AnyDropDelegate(
                isTargeted: $isFileDropped.animation(.linear(duration: 0.1)),
                onValidate: { dropInfo in
                    validateDropInfo(dropInfo)
                },
                onPerform: { dropInfo in
                    handleDropInfo(dropInfo)
                }
            ))
            .border(isFileDropped ? Color.accentColor : .clear, width: 5)
            .toolbar {
                ToolbarItem(id: "back",
                            placement: .navigation,
                            showsByDefault: notOnStartView()) {
                    Button(action: backToFileView) {
                        Image(systemName: "chevron.left")
                    }
                    .help("fileview.toolbar.back")
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                    /// There is a bug preventing the popup being dismissed by clicking "x"
                    .popoverTip(tip, arrowEdge: .leading)
                }
                ToolbarItem(id: "reanalyzeFile",
                            placement: .automatic,
                            showsByDefault: isRequestSuccess()) {
                    Button(action: requestReanalyze) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("toolbar.button.rescan")
                }
            }
            UploadProgressView()
        }
    }

    // MARK: Private

    private let vtWebsite = URL(string: "https://virustotal.com")!
    private var tip = FileNavigationTip()

    /// Action for the toolbar button
    private func backToFileView() {
        viewModel.cancelOngoingRequest()
        viewModel.statusMonitor = .none
        tip.invalidate(reason: .actionPerformed)
    }

    /// Return false if is on case .none, return true otherwise
    private func notOnStartView() -> Bool {
        return viewModel.statusMonitor != .none
    }

    /// Given a sha256 hash, return a URL that can be opened in external browser
    /// to view analysis report on VirusTotal website
    private func makeVtURL(from sha256: String) -> String {
        return "https://www.virustotal.com/gui/file/\(sha256)"
    }

    /// Return true if viewModel.statusMonitor is .success or .analyzing, false otherwise
    private func isUploadFinished() -> Bool {
        return viewModel.statusMonitor == .success || viewModel.statusMonitor == .analyzing
    }

    /// Return true if viewModel.statusMonitor is .success, false otherwise
    private func isRequestSuccess() -> Bool {
        return viewModel.statusMonitor == .success
    }

    private func requestReanalyze() {
        Task {
            viewModel.statusMonitor = .loading
            await viewModel.requestReanalyze()
        }
    }

    /// Return true if viewModel.statusMonitor is .none, .upload, or .success
    private func canDropFile() -> Bool {
        let status = viewModel.statusMonitor
        return status == .none || status == .upload || status == .success
    }

    /// Toggle isFileImporterPresent
    private func onPressFileImporter() {
        isFileImporterPresent.toggle()
    }

    /// Given a DropInfo, return true if DropInfo is `.data` and is a single item, return false otherwise
    private func validateDropInfo(_ dropInfo: DropInfo) -> Bool {
        guard canDropFile() else {
            return false
        }
        let fileURLs = dropInfo.fileURLsConforming(to: [.data])
        return fileURLs.count == 1
    }

    /// Given a DropInfo, handle the dropped item with onPerform
    private func handleDropInfo(_ dropInfo: DropInfo) -> Bool {
        guard let fileURL = dropInfo.fileURLsConforming(to: [.data]).first else {
            return false
        }
        NSApp.activate(ignoringOtherApps: true)
        Task {
            await viewModel.setupFileInfo(fileURL: fileURL)
            await viewModel.getFileReport()
        }
        return true
    }
}

struct AnyDropDelegate: DropDelegate {
    var isTargeted: Binding<Bool>?
    var onValidate: ((DropInfo) -> Bool)?
    let onPerform: (DropInfo) -> Bool
    var onEntered: ((DropInfo) -> Void)?
    var onExited: ((DropInfo) -> Void)?
    var onUpdated: ((DropInfo) -> DropProposal?)?

    func performDrop(info: DropInfo) -> Bool {
        onPerform(info)
    }

    func validateDrop(info: DropInfo) -> Bool {
        onValidate?(info) ?? true
    }

    func dropEntered(info: DropInfo) {
        isTargeted?.wrappedValue = true
        onEntered?(info)
    }

    func dropExited(info: DropInfo) {
        isTargeted?.wrappedValue = false
        onExited?(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        onUpdated?(info)
    }
}

#Preview {
    FileView()
        .frame(minWidth: 600, minHeight: 550)
}
