//
//  BookmarksListView.swift
//  Audiopig
//

import SwiftUI
import UIKit

struct BookmarksListView: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showExportMenu = false
    @State private var shareItems: [Any]? = nil
    @State private var isShareSheetPresented = false

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
                        Haptics.subtle()
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
        .sheet(item: $viewModel.editingBookmark) { bookmark in
            BookmarkEditView(viewModel: viewModel, bookmark: bookmark)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let items = shareItems {
                ShareActivityView(activityItems: items)
            }
        }
    }

    // MARK: - Bookmark List

    private var bookmarkList: some View {
        VStack(spacing: 0) {
            List {
                ForEach(viewModel.bookmarks) { bookmark in
                    Button {
                        viewModel.seekToBookmark(bookmark)
                    } label: {
                        BookmarkRow(bookmark: bookmark) {
                            viewModel.editingBookmark = bookmark
                        }
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

            exportFooter
        }
    }

    // MARK: - Export Footer

    private var exportFooter: some View {
        Button {
            showExportMenu = true
        } label: {
            Label("Export Bookmarks", systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DS.Color.coral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xs)
        .confirmationDialog("Export Bookmarks", isPresented: $showExportMenu) {
            Button("Copy to Clipboard") {
                UIPasteboard.general.string = viewModel.exportText()
            }
            Button("Share as Text (.txt)") {
                shareFile(content: viewModel.exportText(), filename: exportFilename(ext: "txt"))
            }
            Button("Share as CSV (.csv)") {
                shareFile(content: viewModel.exportCSV(), filename: exportFilename(ext: "csv"))
            }
            Button("Share as Markdown (.md)") {
                shareFile(content: viewModel.exportMarkdown(), filename: exportFilename(ext: "md"))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose export format")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(Color(UIColor.systemGray3))

            Text("No Bookmarks Yet")
                .font(.title3.weight(.semibold))

            Text("Tap the bookmark button to mark your position.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.xl)
    }

    // MARK: - Helpers

    private func exportFilename(ext: String) -> String {
        let safe = (viewModel.audiobook?.title ?? "bookmarks")
            .components(separatedBy: .init(charactersIn: "/\\:*?\"<>|"))
            .joined(separator: "_")
        return "\(safe)_bookmarks.\(ext)"
    }

    private func shareFile(content: String, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        shareItems = [url]
        isShareSheetPresented = true
    }
}

// MARK: - Bookmark Row

private struct BookmarkRow: View {
    let bookmark: Bookmark
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.Color.coral)
                .frame(width: 22)

            if bookmark.title.isEmpty {
                Text(PlayerViewModel.formatTime(bookmark.timestamp))
                    .font(DS.Typography.listBody)
                    .foregroundStyle(DS.Color.secondary)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(bookmark.title)
                        .font(DS.Typography.listBody)
                        .lineLimit(1)
                    Text(PlayerViewModel.formatTime(bookmark.timestamp))
                        .font(DS.Typography.timestamp)
                        .foregroundStyle(DS.Color.secondary)
                }
            }

            Spacer(minLength: 0)

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.Color.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.xs)
        .contentShape(Rectangle())
    }
}
