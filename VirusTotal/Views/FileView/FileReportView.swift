//
//  FileReportView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-02.
//

import SwiftUI

@MainActor
struct FileReportView: View {
    private var viewModel = FileViewModel.shared

    var body: some View {
        VStack {
            Form {
                HStack(alignment: .center) {
                    Spacer()
                    FileTypeView()
                        .padding(.trailing, 30)
                    Spacer()
                    FileChartView()
                    .frame(width: 290, height: 180)
                    .padding(.vertical, 10)
                    .padding(.trailing, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                let maliciousFlag: Int = viewModel.lastAnalysisStats?.malicious ?? 0
                let totalFlag = numOfFlags(
                    analysisStats: viewModel.lastAnalysisStats ?? defaultAnalysisStats
                )

                // Malicious/Total Flag number count message
                Label("vendor.count.label \(maliciousFlag) \(totalFlag)",
                      systemImage: getSystemImage())
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(getFlagCountColor())
                .padding(.horizontal)

                // Community Score count message
                Label("community.score.label \(viewModel.reputation ?? 0)",
                      systemImage: "person.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(getCommunityScoreColor())
                .padding(.horizontal)

                // Last Analysis Date
                Label("analysis.date.label \(viewModel.lastAnalysisDate ?? "")",
                      systemImage: "clock.arrow.circlepath")
                .symbolRenderingMode(.hierarchical)
                .padding(.horizontal)

                // Returned File Type Description
                Label("fileview.file.type \(viewModel.typeDescription ?? "n/a")",
                      systemImage: "doc.circle")
                .symbolRenderingMode(.hierarchical)
                .padding(.horizontal)

                // Returned Unique Sources
                HStack(alignment: .center) {
                    Label("fileview.uniquesource.label \(viewModel.uniqueSources ?? 0)",
                          systemImage: "mappin.circle")
                    .symbolRenderingMode(.hierarchical)
                    Spacer()
                    HelpButtonItemView(
                        helpHeadline: "fileview.uniquesource.help.headline",
                        helpDetails: "fileview.uniquesource.help.details"
                    )
                }
                .padding(.leading)
                .padding(.trailing, 2)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Private

    private let defaultAnalysisStats = FileAnalysisStats(malicious: 0,
                                                         suspicious: 0,
                                                         undetected: 63,
                                                         harmless: 0,
                                                         timeout: 0,
                                                         confirmedTimeout: 0,
                                                         failure: 0,
                                                         typeUnsupported: 14)

    /// Given a FileAnalysisStats, return the number of total flags
    private func numOfFlags(analysisStats: FileAnalysisStats) -> Int {
        return analysisStats.allFlags.sum { $0 }
    }

    /// return `checkmark.circle.fill` when malicious flag is 0, return `exclamationmark.triangle.fill` otherwise
    private func getSystemImage() -> String {
        return viewModel.lastAnalysisStats?.malicious == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    /// return color green if the number of malicious flags is 0, return color red otherwise
    private func getFlagCountColor() -> Color {
        return viewModel.lastAnalysisStats?.malicious == 0 ? .green : .red
    }

    /// return color orange if community score is lower than 0, return primary color otherwise
    private func getCommunityScoreColor() -> Color {
        return viewModel.reputation ?? 0 < 0 ? .orange : .primary
    }
}

#Preview {
    FileReportView()
        .frame(minWidth: 600, minHeight: 500)
}
