//
//  LogEmptyView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-30.
//

import SwiftUI

struct LogEmptyView: View {
    @State private var animateSymbol: Bool = false

    var body: some View {
        Label("logview.empty.title",
              systemImage: "pencil.and.scribble")
        .symbolEffect(.bounce, value: animateSymbol)
        .task { animateSymbol.toggle() }
    }
}

#Preview {
    LogEmptyView()
}
