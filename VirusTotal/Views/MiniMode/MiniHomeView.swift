//
//  MiniHomeView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-14.
//

import SwiftUI

struct MiniHomeView: View {
    @State private var viewModel = QuotaStatusViewModel()

    var body: some View {
        VStack(alignment: .center) {
            HStack(alignment: .center) {
                IndicatorLEDView(statusSuccess: $viewModel.statusSuccess)
                Button(action: viewModel.retryRequest) {
                    Image(systemName: "arrow.circlepath")
                        .font(.title2)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(MiniModeButtonStyle())
                .keyboardShortcut("r")
            }
            .padding(.horizontal)
            .padding(.vertical)
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .shadow(color: .red, radius: 10)
                    .padding(.horizontal)
            }
            Spacer()
        }
        .task {
            await viewModel.performRequest()
        }
    }
}

#Preview {
    MiniHomeView()
        .frame(width: 200, height: 160)
}
