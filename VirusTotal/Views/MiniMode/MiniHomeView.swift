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
        Form {
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
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .shadow(color: .red, radius: 10)
                    .padding(.horizontal)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            viewModel.performRequest()
        }
    }
}

#Preview {
    MiniHomeView()
        .frame(width: 200, height: 160)
}
