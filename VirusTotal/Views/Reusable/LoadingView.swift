//
//  LoadingView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-24.
//

import SwiftUI

/// Given a text, create a loading view with a ProgressView and the text in HStack
struct LoadingView: View {
    @State private var elapsedTime: Double = 0.0
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            HStack(alignment: .center, spacing: 5) {
                ProgressView()
                    .controlSize(.small)
                Text("loading.title.progress (\(String(format: "%.1f", elapsedTime))s)...")
                    .monospacedDigit()
            }
            Spacer()
        }
        .onAppear(perform: startTimer)
        .onDisappear(perform: resetTimer)
    }

    // MARK: Private
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1,
                                     repeats: true) { _ in
            elapsedTime += 0.1
        }
    }

    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        elapsedTime = 0.0
    }
}
