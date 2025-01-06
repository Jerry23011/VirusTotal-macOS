//
//  AboutView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-04.
//

import SwiftUI
import Vortex

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VortexViewReader { proxy in
            ZStack {
                VortexView(.confetti) {
                    Rectangle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .tag("square")

                    Circle()
                        .fill(.white)
                        .frame(width: 16)
                        .tag("circle")
                }
                .ignoresSafeArea(edges: .top)
                .frame(height: 190)

                HStack(alignment: .center, spacing: 30) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 120, height: 120)
                        .padding(.bottom, 30)
                        .onTapGesture {
                            proxy.move(to: CGPoint(x: 90, y: 62))
                            proxy.burst()
                        }
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading) {
                            Text(appName)
                                .font(.system(size: 35, weight: .medium))

                            Text("about.current.version \(version) (\(buildNumber))")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)

                            Spacer()
                            Text(copyrightInfo)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .padding(.bottom)

                        }
                        HStack(spacing: 12) {
                            Button {
                                openURL(URL(string: "https://github.com/Jerry23011/VirusTotal-macOS")!)
                            } label: {
                                Label("about.github.link", systemImage: "star.fill")
                                    .frame(width: 135, height: 20)
                            }

                            Button {
                                openURL(URL(string: "https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/ACKNOWLEDGEMENTS.md")!)
                            } label: {
                                Label("about.contributor.link", systemImage: "bookmark.fill")
                                    .frame(width: 135, height: 20)
                            }
                        }
                        .padding(.bottom, 25)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: 530, height: 190)
            .fixedSize()
            .background {
                Button("") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()
            }
            .task {
                if let window = NSApp.findWindow(WindowID.about) {
                    window.styleMask = [.closable, .fullSizeContentView, .titled, .nonactivatingPanel]
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                }
            }
        }
    }

    // MARK: Private

    private let appName: LocalizedStringResource = "VirusTotal for macOS"
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
    private var copyrightInfo: String {
        Bundle.main.localizedString(
            forKey: "NSHumanReadableCopyright",
            value: "Copyright © 2024-2025 Jerry Zhang. All rights reserved.",
            table: "InfoPlist"
        )
    }
}

#Preview {
    AboutView()
        .frame(width: 530, height: 190)
}
