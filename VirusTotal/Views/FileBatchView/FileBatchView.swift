//
//  FileBatchView.swift
//  VirusTotal
//
//  Created by Jerry on 2025-07-10.
//

import SwiftUI

struct FileBatchView: View {
    @State private var viewModel = FileBatchViewModel.shared
    @State private var isFileImporterPresent: Bool = false
    @State private var isFileDropped: Bool = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                FileBatchHeaderView()

                // Main Content
                mainContentView

                // Bottom Actions
                bottomActionsView
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
                    guard validateDropInfo(dropInfo) else { return false }
                    Task {
                        let handled = await handleDropInfo(dropInfo)
                        if !handled {
                            isFileDropped = false
                            log.error("Failed to read dropped files")
                        }
                    }
                    return true
                }
            ))
            .border(isFileDropped ? Color.accentColor : .clear, width: 5)
            .toolbar {
                ToolbarItem(id: "back",
                            placement: .navigation,
                            showsByDefault: !viewModel.batchFiles.isEmpty) {
                    Button(action: backToMainView) {
                        Image(systemName: "chevron.left")
                    }
                    .help("filebatchview.back.help.headline")
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                }

                ToolbarItem(id: "clearAll",
                            placement: .automatic,
                            showsByDefault: !viewModel.batchFiles.isEmpty) {
                    Button(action: clearAllFiles) {
                        Image(systemName: "trash")
                    }
                    .help("filebatchview.clear.help.headline")
                }
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var mainContentView: some View {
        if viewModel.batchFiles.isEmpty {
            emptyStateView
        } else {
            fileListView
        }
    }

    private var emptyStateView: some View {
        VStack(alignment: .center) {
            Spacer()

            Image(systemName: "document.on.document")
                .font(.system(size: 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            OpenFinderButton(title: "filebatchview.button.open.finder",
                             systemImage: "folder") {isFileImporterPresent = true}
                .frame(width: 200)
                .padding(.top)
                .scaleEffect(isFileDropped ? 1.05 : 1)
                .animation(.spring, value: isFileDropped)
                .keyboardShortcut("o", modifiers: .command)
                .fileImporter(
                    isPresented: $isFileImporterPresent,
                    allowedContentTypes: fileScanContentTypes,
                    allowsMultipleSelection: true
                ) { result in
                    handleFileImporterResult(result)
                }

            Text("filebatchview.button.open.caption")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var fileListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.batchFiles) { batchFile in
                    FileBatchRowView(batchFile: batchFile) {
                        viewModel.removeFile(batchFile)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomActionsView: some View {
        HStack {
            if !viewModel.batchFiles.isEmpty {
                Button("filebatchview.button.add.files", systemImage: "plus") {isFileImporterPresent = true}
                .disabled(viewModel.isProcessing)
                .fileImporter(
                    isPresented: $isFileImporterPresent,
                    allowedContentTypes: fileScanContentTypes,
                    allowsMultipleSelection: true
                ) { result in
                    handleFileImporterResult(result)
                }
            }

            Spacer()

            if !viewModel.batchFiles.isEmpty {
                if viewModel.isProcessing {
                    Button("filebatchview.button.cancle.all", action: cancelAllProcessing)
                } else {
                    Button("filebatchview.button.start.analysis", action: startBatchAnalysis)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(viewModel.hasPreparingArchives)
                }
            }
        }
        .padding(.top)
    }

    // MARK: - Actions

    private func backToMainView() {
        viewModel.clearAllFiles()
    }

    private func clearAllFiles() {
        viewModel.clearAllFiles()
    }

    private func startBatchAnalysis() {
        Task {
            await viewModel.startBatchAnalysis()
        }
    }

    private func cancelAllProcessing() {
        viewModel.cancelAllProcessing()
    }

    private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await viewModel.addFiles(urls)
            }
        case .failure(let error):
            log.error("File Import Error: \(error.localizedDescription)")
        }
    }

    private func validateDropInfo(_ dropInfo: DropInfo) -> Bool {
        return dropInfo.hasFileURLs()
    }

    private func handleDropInfo(_ dropInfo: DropInfo) async -> Bool {
        let providers = dropInfo.itemProviders(for: [.fileURL])
        guard !providers.isEmpty else { return false }

        var fileURLs: [URL] = []
        for provider in providers {
            if let url = await provider.fileURL() {
                fileURLs.append(url)
            } else {
                let fileName = provider.suggestedName ?? "unknown file"
                log.error("Failed to read dropped file: \(fileName)")
            }
        }
        guard !fileURLs.isEmpty else { return false }

        NSApp.activate(ignoringOtherApps: true)
        Task {
            await viewModel.addFiles(fileURLs)
            /// On macOS 26, AnyDropDelegate will not trigger `dropExited()` when releasing the cursor after dropping a file.
            if #available(macOS 26, *) {
                isFileDropped = false
            }
        }
        return true
    }
}

// MARK: - Preview

#Preview {
    FileBatchView()
        .frame(minWidth: 700, minHeight: 600)
}
