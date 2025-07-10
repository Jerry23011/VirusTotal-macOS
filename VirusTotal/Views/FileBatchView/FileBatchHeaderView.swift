//
//  FileBatchHeaderView.swift
//  VirusTotal
//
//  Created by Jerry on 2025-07-10.
//

import SwiftUI

struct FileBatchHeaderView: View {
    private var viewModel = FileBatchViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("filebatchview.title")
                .font(.title)
                .frame(maxWidth: .infinity, maxHeight: 0, alignment: .leading)
                .padding(.top)

            if !viewModel.batchFiles.isEmpty {
                HStack {
                    Text("filebatchview.header.number.selected \(viewModel.batchFiles.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Overall progress
                    if viewModel.isProcessing {
                        HStack(spacing: 8) {
                            Text("filebatchview.header.progress \(viewModel.completedCount)/\(viewModel.batchFiles.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ProgressView(value: viewModel.overallProgress)
                                .frame(width: 100)
                        }
                    }
                }
                .frame(height: 30)
            }
        }
    }
}

#Preview {
    FileBatchHeaderView()
}
