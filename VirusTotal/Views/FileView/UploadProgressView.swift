//
//  UploadProgressView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-02.
//

import SwiftUI

struct UploadProgressView: View {
    private var viewModel = FileViewModel.shared

    var body: some View {
        GeometryReader { geometry in
            if viewModel.statusMonitor == .uploading {
                content
                    .frame(maxWidth: .infinity)
                    .padding(.top, geometry.safeAreaInsets.top + 65)
                    .transition(
                        .move(edge: .top)
                        .combined(with: .opacity)
                    )
                    .zIndex(999)
            }
        }
        .ignoresSafeArea(edges: .top)
        .animation(.bouncy, value: viewModel.statusMonitor)
    }

    private var content: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(.regularMaterial)
                .frame(width: 260, height: 40)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 13)
                        .stroke(.gray, lineWidth: 0.2))
            HStack {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 3)
                ProgressView(value: viewModel.uploadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 110)
                Text("fileview.indicator.uploading")
                    .padding(.leading, 3)
            }
        }
    }
}

#Preview {
    UploadProgressView()
        .frame(width: 600, height: 800)
}
