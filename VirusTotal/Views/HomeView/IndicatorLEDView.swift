//
//  IndicatorLEDView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-20.
//

import SwiftUI

struct IndicatorLEDView: View {
    @Binding var statusSuccess: Bool?
    @State private var currentColor = Color.yellow

    var body: some View {
        ZStack {
            Circle()
                .frame(width: 20, height: 20)
                .foregroundColor(currentColor.opacity(0.3))
                .blur(radius: 5)
                .onChange(of: statusSuccess) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        switch newValue {
                        case true:
                            currentColor = .green
                        case false:
                            currentColor = .red
                        default:
                            currentColor = .yellow
                        }
                    }
                }
            Circle()
                .frame(width: 12, height: 12)
                .foregroundColor(currentColor)
                .animation(.easeInOut(duration: 0.3), value: currentColor)
        }
        .padding(.horizontal, 15)
    }
}

#Preview {
    IndicatorLEDView(statusSuccess: .constant(nil))
}
