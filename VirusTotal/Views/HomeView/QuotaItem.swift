//
//  QuotaItem.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-21.
//

import SwiftUI
import Charts

/// Given a title, a systemImage, and a quotaItem, create a QuotaItem for HomeView
struct QuotaItem: View {
    let title: LocalizedStringKey
    let systemImage: String
    let quotaItem: UserQuota

    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: systemImage)
                .frame(maxWidth: 20, maxHeight: 20)
                .font(.system(size: 20))
                .padding(.horizontal, 15)
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3)
                    .foregroundStyle(.primary)
                Text("homepage.quota.used \(quotaItem.used) \(quotaItem.allowed)")
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: Double(quotaItem.used)))
            }
            Spacer()
            Chart(quotaUsage, id: \.name) { element in
              SectorMark(
                angle: .value(String("Usage"), element.usage),
                innerRadius: .ratio(0.618),
                angularInset: 0.5
              )
              .cornerRadius(1)
              .foregroundStyle(by: .value(String("Name"), element.name))
            }
            .chartLegend(.hidden)
            .frame(maxWidth: 30, maxHeight: 30)
            .padding(.trailing, 15)
        }
        .frame(height: 45)
        .animation(.easeInOut, value: quotaItem.used)
    }

    // MARK: Private

    private var unusedQuota: Int {
        return quotaItem.allowed - quotaItem.used
    }

    private var quotaUsage: [QuotaUsage] {
        return [
            .init(name: "Used", usage: quotaItem.used),
            .init(name: "Unused", usage: unusedQuota)
        ]
    }
}

struct QuotaUsage {
    let name: String
    let usage: Int
}
