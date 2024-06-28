//
//  LaunchView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-03.
//

import SwiftUI

@MainActor
struct LaunchView: View {
    @Environment(\.dismiss) var dismiss
    private var viewModel = QuotaStatusViewModel.shared

    var body: some View {
        VStack(alignment: .center) {
            HStack(alignment: .center) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 50, height: 50)
                Text("launchview.setup.title")
                    .font(.title.bold())
            }
            .padding(.top, 30)
            .padding(.horizontal)
            VTSetupView()
            Text("launchview.prompt.signup")
                .padding(.bottom, 1)
            Text("launchview.prompt.getapi")
                .padding(.bottom, 25)
            Text("launchview.prompt.setting")
                .padding(.bottom, 15)
            Button(action: dismissActions) {
                Text("launchview.button.done")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(width: 170)
            .padding(.bottom)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }

    // MARK: Private

    private func dismissActions() {
        dismiss()
        viewModel.retryRequest()
    }
}

#Preview {
    LaunchView()
        .frame(width: 400, height: 430)
}
