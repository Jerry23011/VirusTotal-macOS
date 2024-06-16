//
//  TipsView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-05.
//

import TipKit

struct FileNavigationTip: Tip {
    var title: Text {
        Text("fileview.tip.nav.title")
    }
    var message: Text? {
        Text("fileview.tip.nav.message")
    }
    var image: Image? {
        Image(systemName: "doc.fill.badge.plus")
            .symbolRenderingMode(.hierarchical)
    }
    var options: [Option] {
        Tips.MaxDisplayCount(1)
    }
}

struct FileWaitTimeTip: Tip {

    @Parameter
    static var isWaitTooLong: Bool = false

    var title: Text {
        Text("fileview.tip.wait.title")
    }
    var message: Text? {
        Text("fileview.tip.wait.message")
    }
    var image: Image? {
        Image(systemName: "hourglass")
            .symbolRenderingMode(.hierarchical)
    }
    var options: [Option] {
        Tips.MaxDisplayCount(1)
    }

    var rules: [Rule] {[
        #Rule(Self.$isWaitTooLong) { $0 == true }
    ]}
}
