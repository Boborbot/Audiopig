//
//  ChaptersListView.swift
//  Audiopig
//

import SwiftUI

struct ChaptersListView: View {
    let viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.chapters.enumerated()), id: \.element.id) { index, chapter in
                    Button {
                        viewModel.seekToChapter(chapter)
                    } label: {
                        ChapterRow(
                            chapter: chapter,
                            isActive: index == viewModel.currentChapterIndex
                        )
                    }
                    .buttonStyle(.plain)
                    .coralActiveIndicator(isActive: index == viewModel.currentChapterIndex)
                    .listRowBackground(
                        index == viewModel.currentChapterIndex
                            ? DS.Color.coralSubtle.opacity(0.6)
                            : Color.clear
                    )
                }
            }
            .listStyle(.plain)
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
}

// MARK: - Chapter Row

private struct ChapterRow: View {
    let chapter: Chapter
    let isActive: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(chapter.title)
                    .font(isActive ? DS.Typography.listBody.bold() : DS.Typography.listBody)
                    .foregroundStyle(isActive ? DS.Color.coral : DS.Color.primary)
                    .lineLimit(2)

                Text(PlayerViewModel.formatTime(chapter.duration))
                    .font(DS.Typography.timestamp)
                    .foregroundStyle(DS.Color.secondary)
            }

            Spacer(minLength: 0)

            if isActive {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, isActive: true)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DS.Color.coral)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .contentShape(Rectangle())
    }
}
