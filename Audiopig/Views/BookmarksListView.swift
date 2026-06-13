//
//  BookmarksListView.swift
//  Audiopig
//

import SwiftUI

struct BookmarksListView: View {
    let viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.bookmarks.isEmpty {
                    emptyState
                } else {
                    bookmarkList
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.addBookmark()
                    } label: {
                        Label("Add", systemImage: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Color.coral)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.coral)
                }
            }
        }
        .sheetGlass()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Bookmark List

    private var bookmarkList: some View {
        List {
            ForEach(viewModel.bookmarks) { bookmark in
                Button {
                    viewModel.seekToBookmark(bookmark)
                } label: {
                    BookmarkRow(bookmark: bookmark)
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                let sorted = viewModel.bookmarks
                for index in indexSet.reversed() {
                    guard index < sorted.count else { continue }
                    viewModel.deleteBookmark(sorted[index])
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(Color(UIColor.systemGray3))

            Text("No Bookmarks Yet")
                .font(.title3.weight(.semibold))

            Text("Tap + to mark the current position.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.xl)
    }
}

// MARK: - Bookmark Row

private struct BookmarkRow: View {
    let bookmark: Bookmark

    var body: some View {
        HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.Color.coral)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(bookmark.title)
                    .font(DS.Typography.listBody)
                    .lineLimit(1)

                Text(PlayerViewModel.formatTime(bookmark.timestamp))
                    .font(DS.Typography.timestamp)
                    .foregroundStyle(DS.Color.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.xs)
        .contentShape(Rectangle())
    }
}
