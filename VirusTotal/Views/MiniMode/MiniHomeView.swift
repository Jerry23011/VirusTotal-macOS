//
//  MiniHomeView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-14.
//

import SwiftUI

struct MiniHomeView: View {
    @StateObject private var viewModel = QuotaStatusViewModel()

    var body: some View {
        VStack {
            Form {
                HStack(alignment: .center) {
                    IndicatorLEDView(statusSuccess: $viewModel.statusSuccess)
                    Spacer()
                    IndicatorLEDView(statusSuccess: $viewModel.statusSuccess)
                }
                .padding(.horizontal, 15)
            }
            .formStyle(.grouped)

            Button(action: viewModel.retryRequest) {
                Image(systemName: "arrow.circlepath")
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(MiniModeButtonStyle())
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
            .keyboardShortcut("r")
        }
        .onAppear {
            viewModel.performRequest()
        }
    }
}

#Preview {
    MiniHomeView()
        .frame(width: 200, height: 160)
}
