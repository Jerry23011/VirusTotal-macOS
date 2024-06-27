//
//  FinalURLView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-06.
//

import SwiftUI
import Defaults

struct FinalURLView: View {
    @ObservedObject private var viewModel = URLViewModel.shared

    var body: some View {
        HStack(alignment: .center) {
            if cleanURL {
                HStack(alignment: .center) {
                    Image(systemName: "cursorarrow.click")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 14))
                    Link(viewModel.finalURLClean,
                         destination: URL(string: viewModel.finalURLClean) ?? vtWebsite)
                    .lineLimit(3)
                    .padding(.leading, 2)
                }
            } else {
                Label("\(viewModel.finalURL)", systemImage: "cursorarrow.and.square.on.square.dashed")
                .symbolRenderingMode(.hierarchical)
                .lineLimit(3)
                .textSelection(.enabled)
            }
            Spacer()
            HelpButtonItemView(
                helpHeadline: "urlview.finalurl.help.headline",
                helpDetails: "urlview.finalurl.help.details"
            )
        }
    }

    // MARK: Private

    private let vtWebsite = URL(string: "https://virustotal.com")!

    private var cleanURL: Bool { Defaults[.cleanURL] }
}

#Preview {
    FinalURLView()
}
