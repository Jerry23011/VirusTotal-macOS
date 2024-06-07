//
//  APITab.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import Defaults

struct APITab: View {
    var body: some View {
        VTSetupView()
            .overlay(alignment: .bottomTrailing) {
                HelpButtonItemView(
                    helpHeadline: "settings.api.help.headline",
                    helpDetails: "settings.api.help.details"
                )
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }
    }
}

#Preview {
    APITab()
        .frame(width: 500, height: 400)
}
