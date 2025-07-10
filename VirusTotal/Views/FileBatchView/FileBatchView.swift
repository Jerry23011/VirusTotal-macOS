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
                    handleDropInfo(dropInfo)
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
                    .help("Go back to single file view")
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                }

                ToolbarItem(id: "clearAll",
                            placement: .automatic,
                            showsByDefault: !viewModel.batchFiles.isEmpty) {
                    Button(action: clearAllFiles) {
                        Image(systemName: "trash")
                    }
                    .help("Clear all files")
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
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 12) {
                Text("Select Multiple Files for Batch Analysis")
                    .font(.title2)
                    .multilineTextAlignment(.center)

                Text("Choose multiple files to analyze them all at once")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            OpenFinderButton(title: "fileview.button.open.finder",
                             systemImage: "folder") {isFileImporterPresent = true}
                .frame(width: 200)
                .scaleEffect(isFileDropped ? 1.05 : 1)
                .animation(.spring, value: isFileDropped)
                .keyboardShortcut("o", modifiers: .command)
                .fileImporter(
                    isPresented: $isFileImporterPresent,
                    allowedContentTypes: [.data],
                    allowsMultipleSelection: true
                ) { result in
                    handleFileImporterResult(result)
                }

            Text("Or drag and drop files here")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    private var fileListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.batchFiles) { batchFile in
                    BatchFileRowView(batchFile: batchFile) {
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
                Button("Add More Files", systemImage: "plus") {isFileImporterPresent = true}
                .disabled(viewModel.isProcessing)
                .fileImporter(
                    isPresented: $isFileImporterPresent,
                    allowedContentTypes: [.data],
                    allowsMultipleSelection: true
                ) { result in
                    handleFileImporterResult(result)
                }
            }

            Spacer()

            if !viewModel.batchFiles.isEmpty {
                if viewModel.isProcessing {
                    Button("Cancel All", action: cancelAllProcessing)
                        .foregroundColor(.red)
                } else {
                    Button("Start Batch Analysis", action: startBatchAnalysis)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: .command)
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
        let fileURLs = dropInfo.fileURLsConforming(to: [.data])
        return !fileURLs.isEmpty
    }

    private func handleDropInfo(_ dropInfo: DropInfo) -> Bool {
        let fileURLs = dropInfo.fileURLsConforming(to: [.data])
        guard !fileURLs.isEmpty else { return false }

        NSApp.activate(ignoringOtherApps: true)
        Task {
            await viewModel.addFiles(fileURLs)
        }
        return true
    }
}

// MARK: - BatchFileRowView

struct BatchFileRowView: View {
    let batchFile: BatchFile
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // File Icon
            if let thumbnailImage = batchFile.thumbnailImage {
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }

            // File Info
            VStack(alignment: .leading, spacing: 4) {
                Text(batchFile.fileName)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text(formatFileSize(batchFile.fileSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let typeDescription = batchFile.typeDescription {
                        Text("• \(typeDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Status & Progress
            statusView

            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(batchFile.status == .uploading || batchFile.status == .analyzing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var statusView: some View {
        switch batchFile.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .uploading:
            VStack(alignment: .trailing, spacing: 4) {
                ProgressView(value: batchFile.uploadProgress)
                    .frame(width: 60)
                Text("\(Int(batchFile.uploadProgress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .analyzing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Analyzing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .success:
            if let stats = batchFile.analysisStats {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stats.malicious > 0 ? .red : .green)
                            .frame(width: 8, height: 8)
                        Text(stats.malicious > 0 ? "Malicious" : "Clean")
                            .font(.caption)
                            .foregroundStyle(stats.malicious > 0 ? .red : .green)
                    }
                    Text("\(stats.malicious + stats.suspicious)/\(stats.allFlags.sum { $0 })")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .upload:
            Text("Ready")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Preview

#Preview {
    FileBatchView()
        .frame(minWidth: 700, minHeight: 600)
}
