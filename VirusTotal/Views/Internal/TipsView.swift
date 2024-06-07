//
//  TipsView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-05.
//

import TipKit

struct FileNavigationTip: Tip {
    var title: Text {
        Text("fileview.tip.title")
    }
    var message: Text? {
        Text("fileview.tip.message")
    }
    var image: Image? {
        Image(systemName: "doc.fill.badge.plus")
            .symbolRenderingMode(.hierarchical)
    }
    var options: [Option] {
        Tips.MaxDisplayCount(1)
    }
}
