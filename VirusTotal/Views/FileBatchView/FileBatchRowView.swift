//
//  FileBatchRowView.swift
//  VirusTotal
//
//  Created by Jerry on 2025-07-22.
//

import SwiftUI

struct FileBatchRowView: View {
    @State private var showErrorPopover = false
    let batchFile: BatchFile
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // File Icon
            if batchFile.status == .preparingArchive {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 30, height: 35)
            } else if let thumbnailImage = batchFile.thumbnailImage {
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .frame(width: 30, height: 35)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .shadow(radius: 0.75, y: 1)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 35)
            }

            // File Info
            VStack(alignment: .leading, spacing: 4) {
                Text(batchFile.fileName)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    if batchFile.status == .preparingArchive {
                        Text("filebatchview.text.creating.archive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(formatFileSize(batchFile.fileSize))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let typeDescription = batchFile.typeDescription {
                            Text("filebatchview.type.description \(typeDescription)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Status & Progress
            statusView

            // Remove Button
            if batchFile.status == .preparingArchive || batchFile.status == .preparing {
                EmptyView()
            } else if batchFile.status != .uploading && batchFile.status != .analyzing && batchFile.status != .success {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: openOnVt) {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(batchFile.status == .uploading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(batchFile.status == .preparingArchive ? Color.gray.opacity(0.12) : Color(NSColor.controlBackgroundColor))
        .opacity(batchFile.status == .preparingArchive ? 0.65 : 1)
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
                Text(batchFile.uploadProgress, format: .percent)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .analyzing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("filebatchview.text.analyzing")
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
                        Text(stats.malicious > 0 ? "filebatchview.text.malicious" : "filebatchview.text.clean")
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
                .popover(isPresented: $showErrorPopover) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("filebatchview.error.title")
                            .font(.headline)
                        Text(batchFile.errorMessage ?? "Unknown error")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("filebatchview.error.dismiss") {
                            showErrorPopover = false
                        }
                    }
                    .padding(.vertical)
                    .frame(width: 200)
                }
                .onTapGesture {
                    showErrorPopover.toggle()
                }
        case .upload:
            Text("filebatchview.text.ready")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .preparingArchive:
            Text("filebatchview.text.preparing")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .preparing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("filebatchview.text.analyzing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Private

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func openOnVt() {
        NSWorkspace.shared.open(
            URL(string: "https://www.virustotal.com/gui/file/\(batchFile.sha256)") ?? URL(string: "https://virustotal.com")!
        )
    }
}
