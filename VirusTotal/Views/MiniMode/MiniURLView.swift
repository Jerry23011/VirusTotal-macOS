//
//  MiniURLView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-14.
//

import SwiftUI

struct MiniURLView: View {
    @StateObject private var viewModel = URLViewModel()
    @FocusState private var isTextFieldFocused: Bool
    @State private var isURLOpened: Bool = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .center) {
            TextField("urlview.textfield.placeholder",
                      text: $viewModel.inputURL)
            .lineLimit(1)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .focused($isTextFieldFocused, key: "l", modifiers: .command)
            .onSubmit {
                submitScan()
            }
            .onExitCommand {
                isTextFieldFocused = false
            }
            Button(action: submitScan) {
                if isLoading(viewModel.statusMonitor) {
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
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .buttonStyle(MiniModeButtonStyle())
            Spacer()

        }
        .padding()
        .onChange(of: viewModel.statusMonitor) {
            switch canOpenURL() {
            case true:
                openURL(URL(string: viewModel.vtURL) ?? vtWebsite)
                isURLOpened = true
            case false:
                break
            }
        }
    }

    // MARK: Private
    private let vtWebsite = URL(string: "https://virustotal.com")!

    /// Return true if viewModel.statusMonitor is .success or .analyzing, false otherwise
    private func canOpenURL() -> Bool {
        /// Prevent the URL from being opened the second time if the URL has already
        /// been opened once when statusMonitor change to .analyzing
        guard !isURLOpened else {
            return false
        }
        return viewModel.statusMonitor == .success || viewModel.statusMonitor == .analyzing
    }

    /// Given an AnalysisStatus, return true if viewModel.statusMonitor is .loading, .uploading, or .analyzing, return false otherwise
    private func isLoading(_ status: AnalysisStatus) -> Bool {
        return status == .loading || status == .uploading || status == .analyzing
    }

    private func submitScan() {
        viewModel.errorMessage = ""
        viewModel.vtURL = ""
        viewModel.finalURL = ""
        viewModel.finalURLHost = ""
        viewModel.lastAnalysisTime = ""
        viewModel.startURLAnalysis()
        isTextFieldFocused = false
        isURLOpened = false
    }
}

#Preview {
    MiniURLView()
        .frame(width: 200, height: 160)
}
