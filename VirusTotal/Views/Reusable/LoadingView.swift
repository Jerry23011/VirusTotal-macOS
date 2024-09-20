//
//  LoadingView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-24.
//

import SwiftUI
import TipKit

struct LoadingView: View, Sendable {
    @State private var elapsedTime: Double = 0.0
    @State private var timerTask: Task<Void, Never>?

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
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                elapsedTime += 0.1
            }
        }
    }

    private func resetTimer() {
        timerTask?.cancel()
        timerTask = nil
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
