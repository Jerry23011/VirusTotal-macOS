//
//  URLInfoView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-29.
//

import SwiftUI

struct URLInfoView: View {
    let finalURLHost: String

    var body: some View {
        HStack(alignment: .center) {
            Button(action: copyToPasteboard) {
                Image(systemName: "doc.on.doc.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 12))
            }
            .buttonStyle(BorderlessButtonStyle())
            Text(finalURLHost)
                .textSelection(.enabled)
        }
    }

    // MARK: Private

    private func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(finalURLHost, forType: .string)
    }
}

#Preview {
    URLInfoView(finalURLHost: "www.example.com")
        .frame(minWidth: 200, minHeight: 100)
}
