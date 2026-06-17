//
//  FolderContentView.swift
//  Audiopig
//

import SwiftUI

struct FolderContentView: View {
    let folder: Folder
    let viewModel: LibraryViewModel

    var body: some View {
        ZStack {
            DS.Color.canvas.ignoresSafeArea()

            if viewModel.sortedAudiobooks(in: folder).isEmpty {
                emptyState
            } else {
                bookList
            }
        }
        .navigationTitle(folder.title)
        .navigationBarTitleDisplayMode(.large)
        .coralNavigationBanner()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
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
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Order files")
            }
        }
    }

    // MARK: - Book List

    private var bookList: some View {
        List {
            ForEach(viewModel.sortedAudiobooks(in: folder)) { audiobook in
                AudiobookRowView(
                    audiobook: audiobook,
                    isSelectionModeActive: false,
                    isSelected: false,
                    onTap: { viewModel.openPlayer(for: audiobook) },
                    onToggleSelection: {}
                )
                .libraryCard()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: DS.Spacing.xs,
                    leading: 0,
                    bottom: DS.Spacing.xs,
                    trailing: 0
                ))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    finishSwipeAction(for: audiobook)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    removeSwipeAction(for: audiobook)
                    deleteSwipeAction(for: audiobook)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Swipe Actions

    @ViewBuilder
    private func finishSwipeAction(for audiobook: Audiobook) -> some View {
        if audiobook.isFinished {
            Button {
                viewModel.markUnfinished(audiobook)
            } label: {
                Label("Unfinish", systemImage: "arrow.counterclockwise")
            }
            .tint(DS.Color.coral.opacity(0.6))
        } else {
            Button {
                viewModel.markFinished(audiobook)
            } label: {
                Label("Finished", systemImage: "checkmark.circle.fill")
            }
            .tint(DS.Color.coral)
        }
    }

    private func removeSwipeAction(for audiobook: Audiobook) -> some View {
        Button {
            viewModel.removeFromFolder(audiobook)
        } label: {
            Label("Remove", systemImage: "folder.badge.minus")
        }
        .tint(Color(UIColor.systemOrange))
    }

    private func deleteSwipeAction(for audiobook: Audiobook) -> some View {
        Button(role: .destructive) {
            viewModel.requestDelete(audiobook)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "folder")
                .font(.system(size: 52))
                .foregroundStyle(Color(UIColor.systemGray3))

            Text("Empty Folder")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DS.Color.primary)

            Text("All books have been removed from this folder.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.xl)
    }
}
