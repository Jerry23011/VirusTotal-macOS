//
//  FileTypeView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-03.
//

import SwiftUI

struct FileTypeView: View {
    private var viewModel = FileViewModel.shared

    var body: some View {
        VStack(alignment: .center) {
            if let image = viewModel.thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
            } else {
                Image(systemName: "doc.questionmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
            }
            Text(String(viewModel.fileName?.split(separator: ".").last ?? "n/a"))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    FileTypeView()
        .frame(width: 180, height: 180)
}
