//
//  MiniFileView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-14.
//

import SwiftUI

struct MiniFileView: View {
    @State private var viewModel = FileViewModel()
    @Environment(\.openURL) private var openURL

    @State private var isFileImporterPresent: Bool = false
    @State private var isFileDropped: Bool = false

    var body: some View {
        VStack {
            switch viewModel.statusMonitor {
            case .none, .success:
                noneAndSuccess
            case .upload, .uploading, .fail, .analyzing:
                upload
            case .empty, .loading: // Will never be used in MiniFileView
                EmptyView()
            }
        }
        .modifier(FileDropModifier(dropped: isFileDropped))
    }

    // MARK: ViewBuilders
    @ViewBuilder
    private var noneAndSuccess: some View {
        VStack(alignment: .center) {
            OpenFinderButton(title: "fileview.button.open.finder",
                             systemImage: "folder",
                             action: onPressFileImporter)
            .padding(.top)
            .scaleEffect(isFileDropped ? 1.05 : 1)
            .animation(.spring, value: isFileDropped)
            .keyboardShortcut("o")
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
            Text("minimode.file.drag.file")
            Spacer()
        }
        .padding(.horizontal)
        .onDrop(of: [.fileURL], delegate: AnyDropDelegate(
            isTargeted: $isFileDropped.animation(.linear(duration: 0.1)),
            onValidate: { dropInfo in
                validateDropInfo(dropInfo)
            },
            onPerform: { dropInfo in
                handleDropInfo(dropInfo)
            }
        ))
        .onChange(of: viewModel.statusMonitor) {
            if shouldOpenURL() {
                openURL(URL(string: makeVtURL(viewModel.inputSHA256)) ?? vtWebsite)
                viewModel.statusMonitor = .none
            }
        }
    }

    @ViewBuilder
    private var upload: some View {
        VStack(alignment: .center) {
            Button(action: uploadFile) {
                if viewModel.statusMonitor == .uploading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.statusMonitor == .fail {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                        .symbolRenderingMode(.hierarchical)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Image(systemName: "doc.badge.arrow.up.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .buttonStyle(MiniModeButtonStyle())
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(isUploading())
            .padding(.top)
            Text(viewModel.fileName ?? "n/a")
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal)
        .onChange(of: viewModel.statusMonitor) {
            if shouldOpenURL() {
                openURL(URL(string: makeVtURL(viewModel.inputSHA256)) ?? vtWebsite)
                viewModel.statusMonitor = .none
            }
        }
    }

    // MARK: Modifier
    private struct FileDropModifier: ViewModifier {
        var dropped: Bool

        func body(content: Content) -> some View {
            if #available(macOS 15, *) {
                content
                    .border(dropped ? Color.accentColor : .clear, width: 5)
            } else {
                content
                    .overlay(RoundedRectangle(cornerRadius: 7)
                            .inset(by: -0.4)
                            .stroke(dropped ? Color.accentColor : .clear, lineWidth: 5))
            }
        }
    }

    // MARK: Private

    private let vtWebsite = URL(string: "https://virustotal.com")!

    /// Return true when statusMonitor is .success or .analyzing, return false otherwise
    private func shouldOpenURL() -> Bool {
        let statusMonitor = viewModel.statusMonitor
        return statusMonitor == .success || statusMonitor == .analyzing
    }

    /// Toggle isFileImporterPresent
    private func onPressFileImporter() {
        isFileImporterPresent.toggle()
    }

    /// Given a DropInfo, return true if DropInfo is `.data` and is a single item, return false otherwise
    private func validateDropInfo(_ dropInfo: DropInfo) -> Bool {
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
            /// On macOS 26, AnyDropDelegate will not trigger `dropExited()` when releasing the cursor after dropping a file.
            if #available(macOS 26, *) {
                isFileDropped = false
            }
        }
        return true
    }

    /// Given a sha256 hash, return a URL that can be opened in external browser
    /// to view analysis report on VirusTotal website
    private func makeVtURL(_ sha256: String) -> String {
        return "https://www.virustotal.com/gui/file/\(sha256)"
    }

    /// Trigger `uploadFile` and call `cancelOngoingRequest` after completion
    private func uploadFile() {
        Task {
            if try await viewModel.uploadFile() {
                viewModel.cancelOngoingRequest()
            }
        }
    }

    /// Return true is statusMonitor is .uploading, false otherwise
    private func isUploading() -> Bool {
        return viewModel.statusMonitor == .uploading
    }
}

#Preview {
    MiniFileView()
        .frame(width: 230, height: 160)
}
