//
//  MiniURLView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-14.
//

import SwiftUI

struct MiniURLView: View {
    @StateObject private var viewModel = AnalyzeURLViewModel()
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .center) {
            TextField("mini.url.urlplaceholder",
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
            switch viewModel.statusMonitor {
            case .success:
                openURL(URL(string: viewModel.vtURL) ?? vtWebsite)
            default:
                break
            }
        }
    }

    // MARK: Private
    private let vtWebsite = URL(string: "https://virustotal.com")!

    /// Return true if viewModel.statusMonitor is .success, false otherwise
    private func isRequestSuccess() -> Bool {
        return viewModel.statusMonitor == .success
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
    }
}

#Preview {
    MiniURLView()
        .frame(width: 200, height: 160)
}
