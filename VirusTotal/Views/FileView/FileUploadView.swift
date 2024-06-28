//
//  FileUploadView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import SwiftUI

struct FileUploadView: View {
    @ObservedObject private var viewModel = FileViewModel.shared

    var body: some View {
            VStack {
                let fileSize = (viewModel.fileSize ?? 0)

                if let image = viewModel.thumbnailImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                } else {
                    Image(systemName: "doc.questionmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                }

                Text("fileview.name.size \(viewModel.fileName ?? "n/a") \(fileSize.chooseUnit())")
                    .padding(.top)
                OpenFinderButton(title: "fileview.button.upload",
                                 systemImage: "square.and.arrow.up",
                                 action: startFileUpload)
                .frame(width: 200)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.statusMonitor == .uploading)
            }
    }

    private func startFileUpload() {
        Task {
            await viewModel.startFileUpload()
        }
    }
}

#Preview {
    FileUploadView()
        .frame(minWidth: 600, minHeight: 500)
}
