//
//  ChaptersListView.swift
//  Audiopig
//

import SwiftUI

struct ChaptersListView: View {
    let viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var editDrafts: [PlayerViewModel.ChapterEditDraft] = []

    var body: some View {
        NavigationStack {
            Group {
                if isEditing {
                    chapterEditList
                } else {
                    chapterBrowseList
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { cancelEditing() }
                            .foregroundStyle(DS.Color.coral)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveEdits() }
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Color.coral)
                            .disabled(editDrafts.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Edit") { beginEditing() }
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Color.coral)
                            .disabled(viewModel.chapters.isEmpty)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Color.coral)
                    }
                }
            }
        }
        .sheetGlass()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(isEditing ? .scrolls : .automatic)
    }

    // MARK: - Browse Mode

    private var chapterBrowseList: some View {
        List {
            ForEach(Array(viewModel.chapters.enumerated()), id: \.element.id) { index, chapter in
                Button {
                    viewModel.seekToChapter(chapter)
                } label: {
                    ChapterRow(
                        chapter: chapter,
                        isActive: index == viewModel.currentChapterIndex,
                        durationText: viewModel.formatSpeedAdjustedDuration(chapter.duration)
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
    }

    // MARK: - Edit Mode

    private var chapterEditList: some View {
        List {
            ForEach($editDrafts) { $draft in
                ChapterEditRow(
                    title: $draft.title,
                    durationText: durationText(for: draft.id)
                )
            }
            .onMove { source, destination in
                editDrafts.move(fromOffsets: source, toOffset: destination)
            }
            .onDelete { indexSet in
                guard editDrafts.count > indexSet.count else { return }
                editDrafts.remove(atOffsets: indexSet)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Actions

    private func beginEditing() {
        editDrafts = viewModel.makeChapterEditDrafts()
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
        editDrafts = []
    }

    private func saveEdits() {
        viewModel.saveChapterEdits(editDrafts)
        isEditing = false
        editDrafts = []
    }

    private func durationText(for chapterID: UUID) -> String {
        guard let chapter = viewModel.chapters.first(where: { $0.id == chapterID }) else {
            return ""
        }
        return viewModel.formatSpeedAdjustedDuration(chapter.duration)
    }
}

// MARK: - Chapter Row

private struct ChapterRow: View {
    let chapter: Chapter
    let isActive: Bool
    let durationText: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(chapter.title)
                    .font(isActive ? DS.Typography.listBody.bold() : DS.Typography.listBody)
                    .foregroundStyle(isActive ? DS.Color.coral : DS.Color.primary)
                    .lineLimit(2)

                Text(durationText)
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

// MARK: - Chapter Edit Row

private struct ChapterEditRow: View {
    @Binding var title: String
    let durationText: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
            TextField("Chapter name", text: $title)
                .font(DS.Typography.listBody)
                .foregroundStyle(DS.Color.primary)

            Spacer(minLength: 0)

            Text(durationText)
                .font(DS.Typography.timestamp)
                .foregroundStyle(DS.Color.secondary)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
