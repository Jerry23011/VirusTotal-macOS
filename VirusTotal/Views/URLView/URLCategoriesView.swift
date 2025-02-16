//
//  URLCategoriesView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-07-15.
//

import SwiftUI

struct URLCategoriesView: View {
    @State private var isPopupPresented: Bool = false
    private var viewModel = URLViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            CategoriesView(data: viewModel.categories.prefix(5))

            if viewModel.categories.count > 5 {
                Text("categories.number.more \(viewModel.categories.count - 5)")
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        isPopupPresented.toggle()
                    }
                    .popover(isPresented: $isPopupPresented) {
                        CategoriesView(data: viewModel.categories)
                            .padding()
                            .frame(minWidth: 250)
                    }
            }
        }
    }
}

private struct CategoriesView<Data: Collection>: View where Data.Element: Hashable & StringProtocol & Sendable {
    let data: Data

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: Alignment(horizontal: .leading,
                                    vertical: .center)) {
            Color.clear
                .frame(height: 1)
                .readSize { size in
                    _availableWidth.wrappedValue = size.width
                }

            CategoriesViewContent(
                availableWidth: availableWidth,
                data: data
            )
        }
    }
}

private struct CategoriesViewContent<Data: Collection>: View where Data.Element: Hashable & StringProtocol & Sendable {
    let availableWidth: CGFloat
    let data: Data

    @State private var elementsSize: [Data.Element: CGSize] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(computeRows(), id: \.self) { rowElements in
                HStack(spacing: 8) {
                    ForEach(rowElements, id: \.self) { element in
                        Text(element)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .font(.system(size: 11))
                            .background(.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                            .overlay(Capsule()
                                .stroke(.blue.opacity(0.2), lineWidth: 1))
                            .fixedSize()
                            .readSize { size in
                                _elementsSize.wrappedValue[element] = size
                            }
                    }
                }
            }
        }
    }

    /// Computes the layout of category items in rows based on available width
    private func computeRows() -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentRow = 0
        var remainingWidth = availableWidth

        for element in data {
            let elementSize = elementsSize[element, default: CGSize(width: availableWidth, height: 1)]

            // Remove category names that are too long
            if elementSize.width > 200 {
                continue
            }

            if remainingWidth - (elementSize.width + 8) >= 0 {
                rows[currentRow].append(element)
            } else {
                currentRow += 1
                rows.append([element])
                remainingWidth = availableWidth
            }

            remainingWidth -= (elementSize.width + 8)
        }

        return rows
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize {
        .zero
    }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

private extension View {
    /// Reads the size of a view and calls the provided closure when the size changes
    func readSize(onChange: @Sendable @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self,
                                value: geometryProxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

#Preview {
    VStack(alignment: .leading) {
        CategoriesView(data: ["web applications",
                              "computersandsoftware",
                              "Information Technology (alphaMountain.ai)",
                              "social networks",
                              "information technology",
                              "information technology"])
        .padding(.top, 5)
    }
    .frame(width: 300)
}
