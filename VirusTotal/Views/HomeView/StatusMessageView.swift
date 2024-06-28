//
//  StatusMessageView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-21.
//

import SwiftUI

struct StatusMessageView: View {
    @Binding var statusSuccess: Bool?
    @Binding var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading) {
            if statusSuccess == true {
                Text("homepage.status.success")
            } else if statusSuccess == false {
                Text("homepage.status.fail")
                Text("\(errorMessage ?? "")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("homepage.status.checking")
                    .transition(.blurReplace)
            }
        }
        .font(.title3)
        .foregroundStyle(.primary)
        .animation(.easeInOut(duration: 0.2), value: statusSuccess)
    }
}

#Preview {
    StatusMessageView(statusSuccess: .constant(nil), errorMessage: .constant(nil))
}
