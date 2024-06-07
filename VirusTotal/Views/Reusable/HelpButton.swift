//
//  HelpButton.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-26.
//
//  https://github.com/buresdv/Cork
//

import SwiftUI

struct HelpButton: NSViewRepresentable {
    var action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .helpButton
        button.title = ""
        button.target = context.coordinator
        button.action = #selector(Coordinator.handleButtonClick)
        return button
    }

    func updateNSView(_: NSButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    class Coordinator: NSObject {
        var parent: HelpButton

        init(parent: HelpButton) {
            self.parent = parent
        }

        @objc func handleButtonClick(_ sender: Any?) {
            parent.action()
        }
    }

    typealias NSViewType = NSButton
}

#Preview {
    HelpButton {

    }
    .frame(width: 100, height: 100)
}
