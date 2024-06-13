//
//  FloatingTabBarView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-14.
//

import SwiftUI

struct FloatingTabBarView: View {
    @EnvironmentObject private var tabModel: TabModel
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation
    private let animationID: UUID = .init()
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                Button {
                    tabModel.activeTab = tab
                } label: {
                    Image(systemName: tab.rawValue)
                        .font(.title3)
                        .foregroundStyle(tabModel.activeTab == tab ? (colorScheme == .dark ? .black : .white) : .primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if tabModel.activeTab == tab {
                                Circle()
                                    .fill(.primary)
                                    .matchedGeometryEffect(id: animationID,
                                                           in: animation)
                            }
                        }
                        .contentShape(.rect)
                        .animation(.bouncy, value: tabModel.activeTab)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .frame(width: 45, height: tabBarHeight)
        .background(.windowBackground)
        .clipShape(.capsule)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(width: 50)
        .contentShape(.capsule)
        .offset(x: tabModel.hideTabBar ? 60 : 0)
        .animation(.snappy, value: tabModel.hideTabBar)
    }

    // MARK: Private
    private let tabBarHeight = CGFloat(Tab.allCases.count * 45)
}

#Preview {
    FloatingTabBarView()
}
