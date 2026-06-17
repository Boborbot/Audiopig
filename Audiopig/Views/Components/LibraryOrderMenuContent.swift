//
//  LibraryOrderMenuContent.swift
//  Audiopig
//

import SwiftUI

/// Sort, filter, and direction controls shared by library list toolbars.
/// Presented in a popover so filter/direction can be toggled without dismissing.
struct LibraryOrderMenuContent: View {
    let viewModel: LibraryViewModel

    private static let filterButtonWidth: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(LibrarySortOrder.allCases) { order in
                Button {
                    viewModel.setLibrarySortOrder(order)
                } label: {
                    menuRow {
                        Text(order.menuTitle)
                        Spacer(minLength: DS.Spacing.lg)
                        if viewModel.librarySortOrder == order {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack(spacing: 0) {
                Button {
                    viewModel.cycleLibraryBookFilter()
                } label: {
                    Text(viewModel.libraryBookFilter.menuTitle)
                        .frame(width: Self.filterButtonWidth, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.toggleLibrarySortDirection()
                } label: {
                    directionIcon
                        .frame(width: 44, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.librarySortDirection.accessibilityLabel)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 11)
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private var directionIcon: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.librarySortDirection == .ascending ? "arrow.up" : "arrow.down")
            Image(systemName: "line.3.horizontal.decrease")
        }
        .font(.body.weight(.medium))
        .foregroundStyle(DS.Color.primary)
    }

    private func menuRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            content()
        }
        .font(.body)
        .foregroundStyle(DS.Color.primary)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

/// Toolbar control that opens the library order panel.
struct LibraryOrderToolbarControl: View {
    let viewModel: LibraryViewModel
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Order files")
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            LibraryOrderMenuContent(viewModel: viewModel)
                .presentationCompactAdaptation(.popover)
                .presentationBackground(.regularMaterial)
        }
    }
}
