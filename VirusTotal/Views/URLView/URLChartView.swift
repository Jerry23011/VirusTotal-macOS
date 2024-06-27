//
//  URLChartView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-24.
//

import SwiftUI
import Charts

/// Given a URLAnalysisStats, return a Pie Chart with data
struct URLChartView: View {
    let analysisStats: URLAnalysisStats

    @State private var animateChart = false

    var body: some View {
        VStack {
            Chart(flagStats, id: \.type) { element in
                SectorMark(
                    // Use String() to avoid string being localized
                    angle: .value(String("Flags"), animateChart ? element.number : 1),
                    innerRadius: .ratio(0.618),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(by: .value(String("Type"), element.type))
            }
            .chartLegend(position: .leading, alignment: .center)
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    let frame = chartProxy.plotFrame.map { geometry[$0] } ?? .zero
                    VStack {
                        Text(String(analysisStats.malicious))
                            .font(.largeTitle.bold())
                            .foregroundStyle(getFontColor())
                        Text(String("/ \(numOfFlags(analysisStats: analysisStats))"))
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
            .animation(.smooth, value: animateChart)
            .task { animateChart = true }
        }
    }

    // MARK: Private

    private var flagStats: [FlagStats] {
        return [
            .init(type: "Undetected", number: analysisStats.undetected),
            .init(type: "Harmless", number: analysisStats.harmless),
            .init(type: "Suspicious", number: analysisStats.suspicious),
            .init(type: "Timeout", number: analysisStats.timeout),
            .init(type: "Malicious", number: analysisStats.malicious)
        ]
    }

    /// Given an URLAnalysisStats, return the total number of flags in the URLAnalysisStats
    private func numOfFlags(analysisStats: URLAnalysisStats) -> Int {
        return analysisStats.allFlags.sum { $0 }
    }

    /// return color green if the number of malicious flags is 0, return color red otherwise
    private func getFontColor() -> Color {
        return analysisStats.malicious == 0 ? .green : .red
    }

}

struct FlagStats {
    let type: String
    let number: Int
}
#Preview {
        URLChartView(analysisStats: URLAnalysisStats(malicious: 1,
                                                suspicious: 0,
                                                undetected: 20,
                                                harmless: 75,
                                                timeout: 0))
        .frame(width: 300, height: 150)
}
