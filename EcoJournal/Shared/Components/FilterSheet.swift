//
//  FilterSheet.swift
//  EcoJournal
//
//  Created by David Contreras on 5/13/26.
//

import SwiftUI

struct FilterSheet<Option: FilterDisplayable>: View {
    @Binding var selectedOption: Option
    @Environment(\.dismiss) var dismiss

    var body: some View {
        let allCases = Array(Option.allCases)

        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sort By")
                    .font(.headline(20, weight: .bold))
                    .foregroundColor(.onSurface)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.tertiaryColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Options list
            VStack(spacing: 0) {
                ForEach(Array(allCases.enumerated()), id: \.element.id) { index, option in
                    Button(action: {
                        selectedOption = option
                        dismiss()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: option.systemImage)
                                .font(.system(size: 18))
                                .foregroundColor(selectedOption == option ? .primaryColor : .secondaryColor)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.rawValue)
                                    .font(.body(16))
                                    .foregroundColor(.onSurface)
                                if let subtitle = option.subtitle {
                                    Text(subtitle)
                                        .font(.label(11))
                                        .foregroundColor(.onSurfaceVariant)
                                }
                            }

                            Spacer()

                            if selectedOption == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primaryColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(selectedOption == option ? Color.primaryContainer.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)

                    if index < allCases.count - 1 {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }

            Spacer()
        }
        .presentationBackground(Color.surfaceBackground)
        .presentationDetents([.height(CGFloat(120 + allCases.count * 56))])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Dashboard filter") {
    FilterSheet(selectedOption: .constant(SortOption.mostRecent))
}

#Preview("Logs filter") {
    FilterSheet(selectedOption: .constant(LogSortOption.creationDate))
}
