//
//  LibraryOrderMenuContent.swift
//  Audiopig
//

import SwiftUI

/// Sort, filter, and direction controls shared by library list toolbars.
struct LibraryOrderMenuContent: View {
    let viewModel: LibraryViewModel

    var body: some View {
        Picker(
            "Order Files",
            selection: Binding(
                get: { viewModel.librarySortOrder },
                set: { viewModel.setLibrarySortOrder($0) }
            )
        ) {
            ForEach(LibrarySortOrder.allCases) { order in
                Text(order.menuTitle).tag(order)
            }
        }

        Divider()

        Button {
            viewModel.cycleLibraryBookFilter()
        } label: {
            Text(viewModel.libraryBookFilter.menuTitle)
        }

        Button {
            viewModel.toggleLibrarySortDirection()
        } label: {
            Image(systemName: viewModel.librarySortDirection.iconName)
        }
        .accessibilityLabel(viewModel.librarySortDirection.accessibilityLabel)
    }
}
