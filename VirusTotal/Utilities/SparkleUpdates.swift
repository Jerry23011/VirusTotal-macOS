//
//  SparkleUpdates.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-08.
//
// https://sparkle-project.org/documentation/programmatic-setup/
//

import SwiftUI
import Sparkle

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater
            .publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("check.for.updates", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}
