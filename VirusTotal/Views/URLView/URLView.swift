//
//  URLView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI

struct URLView: View {

    @StateObject private var viewModel = URLViewModel.shared
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack {
            Text("urlview.title")
                .font(.title)
                .frame(maxWidth: .infinity, maxHeight: 0, alignment: .leading)
                .padding(.vertical)
            // Textfield and Scan button
            HStack(alignment: .center) {
                TextField("urlview.textfield.placeholder", text: $viewModel.inputURL)
                    .lineLimit(1)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused, key: "l", modifiers: .command)
                    .onSubmit {
                        submitScan()
                    }
                    .onExitCommand {
                        // Lose focus when esc is pressed
                        isTextFieldFocused = false
                    }
                Spacer()
                Button(action: submitScan) {
                    Text("urlview.button.scan")
                }
            }
            switch viewModel.statusMonitor {
            case .empty:
                Spacer()
                WelcomeView(title: "urlview.welcome.title",
                            systemImage: "network.badge.shield.half.filled")
                .padding(.bottom, 60)
            case .loading, .uploading, .analyzing:
                LoadingView()
            case .success:
                VStack(alignment: .center) {
                    Form {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading) {
                                // Final URL Host
                                URLInfoView(finalURLHost: viewModel.finalURLHost)
                                // Later implement Rescan button here?
                                Spacer()
                            }
                            .lineLimit(1)
                            .padding(.top, 31)
                            .padding(.leading, 19)

                            Spacer()

                            URLChartView(analysisStats: viewModel.analysisStats ?? defaultAnalysisStats)
                            .frame(width: 250, height: 150)
                            .padding(.vertical, 10)
                            .padding(.trailing, 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        let maliciousFlag: Int = viewModel.analysisStats?.malicious ?? 0
                        let totalFlag = numOfFlags(
                            analysisStats: viewModel.analysisStats ?? defaultAnalysisStats
                        )

                        // Malicious/Total Flag number count message
                        Label("vendor.count.label \(maliciousFlag) \(totalFlag)",
                              systemImage: getSystemImage())
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(getFlagCountColor())
                        .padding(.horizontal)

                        // Community Score count message
                        Label("community.score.label \(viewModel.communityScore)",
                              systemImage: "person.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(getCommunityScoreColor())
                        .padding(.horizontal)

                        // Last Analysis Date
                        Label("analysis.date.label \(viewModel.lastAnalysisTime)",
                              systemImage: "clock.arrow.circlepath")
                        .symbolRenderingMode(.hierarchical)
                        .padding(.horizontal)

                        // Returned Final url (last_final_url)
                        FinalURLView()
                            .padding(.leading)
                            .padding(.trailing, 2)
                    }
                    .formStyle(.grouped)
                    .scrollDisabled(true)
                    .scrollIndicators(.hidden)
                }
            case .fail:
                ErrorView(title: "errorview.title",
                          errorMessage: viewModel.errorMessage ?? "")
            case .upload:  // No such case in URL Analysis
                EmptyView()
            }
            Spacer()
            // Button to visit URL report on VT website
            Button {
                NSWorkspace.shared.open(URL(string: viewModel.vtURL) ?? vtWebsite)
            } label: {
                Label("urlview.button.go.vt", systemImage: "arrowshape.turn.up.right.fill")
                    .symbolEffect(.bounce, value: isRequestSuccess())
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .disabled(!isRequestSuccess())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical)
        .padding(.horizontal, 20)
        .toolbar {
            ToolbarItem(id: "reanalyzeURL",
                        placement: .automatic,
                        showsByDefault: isRequestSuccess()) {
                Button(action: requestReanalyze) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("toolbar.button.rescan")
            }
        }
    }

    // MARK: Private

    private let vtWebsite = URL(string: "https://virustotal.com")!

    private let defaultAnalysisStats = URLAnalysisStats(malicious: 1,
                                                     suspicious: 1,
                                                     undetected: 20,
                                                     harmless: 70,
                                                     timeout: 0)

    private func submitScan() {
        viewModel.errorMessage = ""
        viewModel.vtURL = ""
        viewModel.finalURL = ""
        viewModel.finalURLHost = ""
        viewModel.lastAnalysisTime = ""
        viewModel.startURLAnalysis()
        isTextFieldFocused = false
    }

    /// Return true if viewModel.statusMonitor is .success, false otherwise
    private func isRequestSuccess() -> Bool {
        return viewModel.statusMonitor == .success
    }

    /// Given an URLAnalysisStats, return the total number of flags in the URLAnalysisStats
    private func numOfFlags(analysisStats: URLAnalysisStats) -> Int {
        return analysisStats.allFlags.sum { $0 }
    }

    /// return color green if the number of malicious flags is 0, return color red otherwise
    private func getFlagCountColor() -> Color {
        return viewModel.analysisStats?.malicious == 0 ? .green : .red
    }

    /// return color orange if community score is lower than 0, return primary color otherwise
    private func getCommunityScoreColor() -> Color {
        return viewModel.communityScore < 0 ? .orange : .primary
    }

    /// return `checkmark.circle.fill` when malicious flag is 0, return `exclamationmark.triangle.fill` otherwise
    private func getSystemImage() -> String {
        return viewModel.analysisStats?.malicious == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private func requestReanalyze() {
        viewModel.statusMonitor = .loading
        viewModel.requestReanalyze()
    }
}

#Preview {
    URLView()
        .frame(minWidth: 600, minHeight: 500)
}
