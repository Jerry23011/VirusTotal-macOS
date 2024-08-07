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

    // TODO: Check future versions of Xcode to see if problem got fixed
    // https://forums.developer.apple.com/forums/thread/757291
//     @Parameter
//     static var isWaitTooLong: Bool = false

    static var isWaitTooLong: Bool {
        get {
            isWaitTooLongPH.wrappedValue
        }
        set {
            isWaitTooLongPH.wrappedValue = newValue
        }
    }

    static nonisolated(unsafe) var isWaitTooLongPH = Tips.Parameter<Bool>(Self.self, "+isWaitTooLong", false)

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

    // TODO: Check future versions of Xcode to see if problem got fixed
//    var rules: [Rule] {[
//        #Rule(Self.$isWaitTooLong) { $0 == true }
//    ]}

    var rules: [Rule] {[
        #Rule(FileWaitTimeTip.isWaitTooLongPH) { $0 == true }
    ]}
}
