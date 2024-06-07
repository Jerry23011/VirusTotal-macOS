//
//  ErrorView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-24.
//

import SwiftUI

/// Given a title and error message, make a error view
struct ErrorView: View {
    let title: LocalizedStringKey
    let errorMessage: String

    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.red)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading) {
                    Text(title)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .frame(maxWidth: 400)
    }
}
