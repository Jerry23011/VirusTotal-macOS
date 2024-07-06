//
//  HelpButtonItemView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-26.
//

import SwiftUI

struct HelpButtonItemView: View {
    @State private var isShowingHelpPopover: Bool = false

    let helpHeadline: LocalizedStringKey
    let helpDetails: LocalizedStringKey
    var body: some View {
        HelpButton {
            isShowingHelpPopover.toggle()
        }
        .popover(isPresented: $isShowingHelpPopover) {
            VStack(alignment: .leading, spacing: 10) {
                Text(helpHeadline)
                    .font(.headline)
                Text(helpDetails)
            }
            .padding()
            .frame(width: 300)
        }
    }
}

#Preview {
    HelpButtonItemView(helpHeadline: "urlview.finalurl.help.headline",
                       helpDetails: "urlview.finalurl.help.headline")
}
