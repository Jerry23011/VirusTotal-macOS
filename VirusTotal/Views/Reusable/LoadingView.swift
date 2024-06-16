//
//  LoadingView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-24.
//

import SwiftUI
import TipKit

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
            .popoverTip(tip, arrowEdge: .top)
            Spacer()
        }
        .onAppear(perform: startTimer)
        .onDisappear(perform: resetTimer)
        .onChange(of: elapsedTime, toggleFileWaitTimeTip)
    }

    // MARK: Private

    private var tip = FileWaitTimeTip()

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

    /// Toggle `FileWaitTimeTip.isWaitTooLong` to be true when `elapsedTime`
    /// is larger than 20
    private func toggleFileWaitTimeTip() {
        if self.elapsedTime > 20.0 {
            FileWaitTimeTip.isWaitTooLong = true
        }
    }
}
