//
//  SubtitleSearchSheet.swift
//  Audiopig
//

import SwiftUI
import UIKit

struct SubtitleSearchSheet: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var actionMenuResultID: String?
    @State private var copiedResultID: String?
    @State private var bookmarkedResultID: String?

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchResults: PlayerViewModel.SubtitleSearchResults {
        viewModel.subtitleSearchResults(matching: searchText)
    }

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    searchResultsSection
                } else {
                    coverageIndicatorSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Search Subtitles")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search transcribed text"
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.coral)
                }
            }
            .sensoryFeedback(.success, trigger: copiedResultID)
            .sensoryFeedback(.success, trigger: bookmarkedResultID)
            .onChange(of: searchText) { _, _ in
                actionMenuResultID = nil
            }
        }
        .sheetGlass()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var coverageIndicatorSection: some View {
        Section {
            if viewModel.hasSavedSubtitles {
                SubtitleCoverageCardView(
                    timeline: viewModel.subtitleCoverageTimeline,
                    formatTime: PlayerViewModel.formatTime
                )
                .listRowInsets(EdgeInsets(
                    top: DS.Spacing.sm,
                    leading: DS.Spacing.md,
                    bottom: DS.Spacing.sm,
                    trailing: DS.Spacing.md
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private var searchResultsSection: some View {
        Section {
            if !viewModel.hasSavedSubtitles {
                Text("No transcribed text yet. Generate subtitles from the player or transcribe the entire book from Subtitles options.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.secondary)
            } else if searchResults.items.isEmpty {
                Text("No matches in transcribed sections.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.secondary)
            } else {
                ForEach(searchResults.items) { result in
                    searchResultRow(result)
                }
            }
        } header: {
            Text("Search Results")
        } footer: {
            if viewModel.hasSavedSubtitles, searchResults.totalCount > searchResults.items.count {
                Text("Showing \(searchResults.items.count) of \(searchResults.totalCount) matches.")
                    .font(DS.Typography.caption)
            } else if viewModel.hasSavedSubtitles, !searchResults.items.isEmpty {
                Text("Tap a line to jump to that moment. Long press for copy and bookmark.")
                    .font(DS.Typography.caption)
            }
        }
    }

    // MARK: - Result Row

    private func searchResultRow(_ result: PlayerViewModel.SubtitleSearchResultItem) -> some View {
        ZStack(alignment: .top) {
            SubtitleSearchResultRow(
                text: result.text,
                timestamp: PlayerViewModel.formatTime(result.startTime),
                chapterTitle: result.chapterTitle
            )
            .padding(.top, actionMenuResultID == result.id ? 48 : 0)
            .contentShape(Rectangle())
            .onTapGesture {
                if actionMenuResultID != nil {
                    actionMenuResultID = nil
                } else {
                    viewModel.seekToSubtitleFromSearch(at: result.startTime)
                }
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                Haptics.subtle()
                withAnimation(DS.Animation.snappy) {
                    actionMenuResultID = result.id
                }
            }

            if actionMenuResultID == result.id {
                SubtitleLineActionBubble(
                    onCopy: {
                        copySearchResult(result)
                        actionMenuResultID = nil
                    },
                    onBookmark: {
                        bookmarkSearchResult(result)
                        actionMenuResultID = nil
                    }
                )
                .frame(maxWidth: .infinity)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .zIndex(actionMenuResultID == result.id ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to jump to this moment. Long press for copy and bookmark.")
        .accessibilityAction(named: "Copy") {
            copySearchResult(result)
        }
        .accessibilityAction(named: "Add Bookmark") {
            bookmarkSearchResult(result)
        }
    }

    private func copySearchResult(_ result: PlayerViewModel.SubtitleSearchResultItem) {
        UIPasteboard.general.string = result.text
        copiedResultID = result.id
    }

    private func bookmarkSearchResult(_ result: PlayerViewModel.SubtitleSearchResultItem) {
        viewModel.addBookmarkFromSubtitle(text: result.text, at: result.startTime)
        bookmarkedResultID = result.id
    }
}

// MARK: - Search Result Row

struct SubtitleSearchResultRow: View {
    let text: String
    let timestamp: String
    let chapterTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(text)
                .font(DS.Typography.listBody)
                .foregroundStyle(DS.Color.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DS.Spacing.xs) {
                Text(timestamp)
                    .font(DS.Typography.timestamp)
                    .foregroundStyle(DS.Color.secondary)

                if let chapterTitle {
                    Text("·")
                        .font(DS.Typography.timestamp)
                        .foregroundStyle(DS.Color.tertiary)
                    Text(chapterTitle)
                        .font(DS.Typography.timestamp)
                        .foregroundStyle(DS.Color.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
