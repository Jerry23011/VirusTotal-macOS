//
//  FileBatchView.swift
//  VirusTotal
//
//  Created by Jerry on 2025-06-17.
//

import SwiftUI

struct FileBatchView: View {
    @State private var viewModel = FileViewModel.batch
    @State private var isImporterPresented = false

    // 1. Store your selected file URLs right in the view
    @State private var fileURLs: [URL] = []

    var body: some View {
        VStack {
            HStack {
                Text("Batch Upload")
                    .font(.largeTitle)
                Spacer()
                Button("Add Files") {
                    isImporterPresented = true
                }
                .fileImporter(
                    isPresented: $isImporterPresented,
                    allowedContentTypes: [.data],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        // 2. Append to your local array
                        fileURLs.append(contentsOf: urls)
                    case .failure(let error):
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            .padding()

            List {
                // 3. Iterate the URL array directly
                ForEach(fileURLs, id: \.self) { url in
                    HStack {
                        VStack(alignment: .leading) {
                            // 4. Get the display name straight from the URL
                            Text(url.lastPathComponent)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        // you can still wire up progress & status here if you
                        // want to track them in your view model per-URL
                    }
                }
                .onDelete { offsets in
                    fileURLs.remove(atOffsets: offsets)
                }
            }

            HStack {
                Button("Upload All") {
                    // Kick off your existing batch logic
                    // e.g. loop fileURLs and call handleFileImport(_:)
                    Task {
                        for url in fileURLs {
                            await viewModel.handleFileImport(url)
                        }
                    }
                }
                .disabled(fileURLs.isEmpty)

                Spacer()

                Button("Clear") {
                    fileURLs.removeAll()
                }
                .disabled(fileURLs.isEmpty)
            }
            .padding()
        }
        .padding()
    }
}
