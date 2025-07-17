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
            CategoriesView(categories: Array(viewModel.categories.prefix(5)))

            if viewModel.categories.count > 5 {
                Text("categories.number.more \(viewModel.categories.count - 5)")
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        isPopupPresented.toggle()
                    }
                    .popover(isPresented: $isPopupPresented) {
                        CategoriesView(categories: Array(viewModel.categories))
                            .padding()
                            .frame(minWidth: 250)
                    }
            }
        }
    }
}

private struct CategoriesView: View {
    let categories: [String]

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed height container to prevent layout shifts
            ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
                Color.clear
                    .frame(height: 1)
                    .readSize { size in
                        availableWidth = size.width
                    }

                if availableWidth > 0 {
                    CategoriesViewContent(
                        availableWidth: availableWidth,
                        categories: categories
                    )
                } else {
                    // Placeholder to maintain height during initial layout
                    Text(String(" "))
                        .font(.system(size: 11))
                        .padding(.vertical, 4)
                        .opacity(0)
                }
            }
        }
    }
}

private struct CategoriesViewContent: View {
    let availableWidth: CGFloat
    let categories: [String]

    @State private var elementsSize: [String: CGSize] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(computeRows(), id: \.self) { rowElements in
                HStack(spacing: 6) {
                    ForEach(rowElements, id: \.self) { element in
                        CategoryChip(text: element) { size in
                            elementsSize[element] = size
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Computes the layout of category items in rows based on available width
    private func computeRows() -> [[String]] {
        guard availableWidth > 0 else { return [] }

        var rows: [[String]] = [[]]
        var currentRow = 0
        var remainingWidth = availableWidth

        for element in categories {
            let elementSize = elementsSize[element, default: estimateSize(for: element)]

            // Remove category names that are too long
            if elementSize.width > 200 {
                continue
            }

            // Check if element fits in current row (including spacing)
            let requiredWidth = elementSize.width + (rows[currentRow].isEmpty ? 0 : 6)

            if remainingWidth >= requiredWidth {
                rows[currentRow].append(element)
                remainingWidth -= requiredWidth
            } else {
                // Start new row
                currentRow += 1
                rows.append([element])
                remainingWidth = availableWidth - elementSize.width
            }
        }

        return rows.filter { !$0.isEmpty }
    }

    /// Estimates the size of a category chip before it's actually rendered
    private func estimateSize(for text: String) -> CGSize {
        let font = NSFont.systemFont(ofSize: 11)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        // Add padding: horizontal 16 (8+8), vertical 8 (4+4), plus some buffer
        return CGSize(width: size.width + 20, height: size.height + 10)
    }
}

private struct CategoryChip: View {
    let text: String
    let onSizeChange: @MainActor (CGSize) -> Void

    var body: some View {
        Text(text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .font(.system(size: 11))
            .background(.blue.opacity(0.1))
            .foregroundColor(.blue)
            .clipShape(Capsule())
            .overlay(alignment: .center) {
                Capsule()
                    .stroke(.blue.opacity(0.2), lineWidth: 1)
            }
            .fixedSize()
            .readSize(onChange: onSizeChange)
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        // For size preference, we typically don't need to reduce
        // The latest value is usually what we want
    }
}

private extension View {
    /// Reads the size of a view and calls the provided closure when the size changes
    func readSize(onChange: @escaping @MainActor (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self) { size in
            Task { @MainActor in
                onChange(size)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        CategoriesView(categories: [
            "web applications",
            "computersandsoftware",
            "Information Technology (alphaMountain.ai)",
            "social networks",
            "information technology",
            "information technology"
        ])
        .padding(.top, 5)
    }
    .frame(width: 300)
}
