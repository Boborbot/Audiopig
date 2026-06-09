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
                    .listRowBackground(
                        index == viewModel.currentChapterIndex
                            ? Color.accentColor.opacity(0.08)
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
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Chapter Row

private struct ChapterRow: View {
    let chapter: Chapter
    let isActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.title)
                    .font(isActive ? .body.weight(.semibold) : .body)
                    .foregroundStyle(isActive ? Color.accentColor : .primary)
                    .lineLimit(2)

                Text(PlayerViewModel.formatTime(chapter.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if isActive {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, isActive: true)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
