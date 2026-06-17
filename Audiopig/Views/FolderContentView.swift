//
//  FolderContentView.swift
//  Audiopig
//

import SwiftUI

struct FolderContentView: View {
    let folder: Folder
    let viewModel: LibraryViewModel

    private var folderBooks: [Audiobook] {
        viewModel.sortedAudiobooks(in: folder)
    }

    var body: some View {
        ZStack {
            DS.Color.canvas.ignoresSafeArea()

            if folderBooks.isEmpty {
                emptyState
            } else {
                bookList
            }
        }
        .navigationTitle(folder.title)
        .navigationBarTitleDisplayMode(.large)
        .coralNavigationBanner()
        .toolbar { toolbarItems }
        .onDisappear {
            if viewModel.isSelectionModeActive {
                viewModel.toggleSelectionMode()
            }
        }
    }

    // MARK: - Book List

    private var bookList: some View {
        List {
            ForEach(folderBooks, id: \.id) { audiobook in
                AudiobookRowView(
                    audiobook: audiobook,
                    isSelectionModeActive: viewModel.isSelectionModeActive,
                    isSelected: viewModel.isSelected(audiobook),
                    onTap: { viewModel.openPlayer(for: audiobook) },
                    onToggleSelection: { viewModel.toggleSelection(audiobook) }
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
        .miniPlayerScrollClearance()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if viewModel.isSelectionModeActive {
                Menu {
                    Button(role: .destructive) {
                        viewModel.requestBulkDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(!viewModel.canDeleteSelected)

                    Button {
                        viewModel.presentMergeSheet()
                    } label: {
                        Label("Combine into Volume", systemImage: "rectangle.stack.badge.plus")
                    }
                    .disabled(!viewModel.canMergeSelected)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .transition(.opacity)
            } else if !folderBooks.isEmpty {
                LibraryOrderToolbarControl(viewModel: viewModel)
                    .transition(.opacity)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if !folderBooks.isEmpty {
                Button(viewModel.isSelectionModeActive ? "Done" : "Select") {
                    withAnimation(DS.Animation.standard) {
                        viewModel.toggleSelectionMode()
                    }
                }
                .fontWeight(.medium)
                .animation(nil, value: viewModel.isSelectionModeActive)
            }
        }
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
