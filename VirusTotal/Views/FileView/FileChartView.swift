//
//  FileChartView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-03.
//

import SwiftUI
import Charts

struct FileChartView: View {
    @ObservedObject private var viewModel = FileViewModel.shared

    @State private var animateChart = false

    var body: some View {
        let analysisStats = viewModel.lastAnalysisStats

        VStack {
            Chart(flagStats, id: \.type) { element in
                SectorMark(
                    // Use String() to avoid string being localized
                    angle: .value(String("Flags"), animateChart ? element.number : 1),
                    innerRadius: .ratio(0.618),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(by: .value(String("Type"), element.type.nslocalized))
            }
            .chartLegend(position: .leading, alignment: .center)
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    let frame = chartProxy.plotFrame.map { geometry[$0] } ?? .zero
                    VStack {
                        Text(String(analysisStats?.malicious ?? 0))
                            .font(.largeTitle.bold())
                            .foregroundStyle(getFontColor())
                        Text(String("/ \(numOfFlags(analysisStats: analysisStats ?? defaultAnalysisStats))"))
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
            .animation(.smooth, value: animateChart)
            .onAppear {
                    animateChart = true
            }
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

    private var flagStats: [FlagStats] {
        return [
            .init(type: "flag.type.unsupported",
                  number: viewModel.lastAnalysisStats?.typeUnsupported ?? 0),
            .init(type: "flag.undetected",
                  number: viewModel.lastAnalysisStats?.undetected ?? 0),
            .init(type: "flag.suspicious",
                  number: viewModel.lastAnalysisStats?.suspicious ?? 0),
            .init(type: "flag.failure",
                  number: viewModel.lastAnalysisStats?.failure ?? 0),
            .init(type: "flag.malicious",
                  number: viewModel.lastAnalysisStats?.malicious ?? 0),
            .init(type: "flag.harmless",
                  number: viewModel.lastAnalysisStats?.harmless ?? 0),
            .init(type: "flag.timeout",
                  number: viewModel.lastAnalysisStats?.timeout ?? 0),
            .init(type: "flag.confirmed.timeout",
                  number: viewModel.lastAnalysisStats?.confirmedTimeout ?? 0)
        ]
    }

    /// Given an FileAnalysisStats, return the total number of flags
    private func numOfFlags(analysisStats: FileAnalysisStats) -> Int {
        return analysisStats.allFlags.sum { $0 }
    }

    /// return color green if the number of malicious flags is 0, return color red otherwise
    private func getFontColor() -> Color {
        return viewModel.lastAnalysisStats?.malicious == 0 ? .green : .red
    }
}

#Preview {
    FileChartView()
    .frame(width: 290, height: 170)
}
