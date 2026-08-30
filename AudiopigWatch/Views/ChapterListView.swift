//
//  ChapterListView.swift
//  AudiopigWatch
//

import SwiftUI

struct ChapterListView: View {
    @ObservedObject var viewModel: WatchPlayerViewModel
    let isActive: Bool
    var onChapterSelected: () -> Void

    init(viewModel: WatchPlayerViewModel, isActive: Bool, onChapterSelected: @escaping () -> Void) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.isActive = isActive
        self.onChapterSelected = onChapterSelected
    }

    @State private var scrollPosition: Int?
    @State private var crownScrollIndex: Float = 0
    @FocusState private var crownFocused: Bool

    var body: some View {
        Group {
            if viewModel.chapters.isEmpty {
                VStack(spacing: WDS.Spacing.sm) {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(WDS.Color.coral)
                    Text("No chapters")
                        .font(.caption)
                    Text("Load a book on iPhone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                List(viewModel.chapters.indices, id: \.self) { index in
                    let chapter = viewModel.chapters[index]
                    let isCurrent = index == viewModel.snapshot.chapterIndex

                    Button {
                        viewModel.seekToChapter(at: index)
                        onChapterSelected()
                    } label: {
                        HStack(spacing: WDS.Spacing.sm) {
                            if isCurrent {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(WDS.Color.coral)
                                    .frame(width: 3)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(chapter.title)
                                    .font(isCurrent ? .caption.weight(.semibold) : .caption)
                                    .foregroundStyle(isCurrent ? WDS.Color.coral : .primary)
                                    .lineLimit(2)
                                Text(viewModel.formatSpeedAdjustedDuration(chapter.duration))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(isCurrent ? WDS.Color.coral.opacity(0.15) : Color.clear)
                }
                .listStyle(.plain)
                .scrollPosition(id: $scrollPosition)
                .focusable(isActive)
                .focused($crownFocused)
                .watchDigitalCrownMedium(
                    isActive: isActive,
                    value: $crownScrollIndex,
                    from: 0,
                    through: Float(max(0, viewModel.chapters.count - 1)),
                    by: 1,
                    isContinuous: false,
                    isHapticFeedbackEnabled: false
                )
                .onChange(of: crownScrollIndex) { _, newValue in
                    scrollPosition = Int(newValue.rounded())
                }
            }
        }
        .onAppear {
            scrollPosition = viewModel.snapshot.chapterIndex
            crownScrollIndex = Float(viewModel.snapshot.chapterIndex)
            if isActive {
                claimCrownFocus()
            }
            Task {
                await viewModel.requestChaptersIfNeeded()
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                claimCrownFocus()
            } else {
                crownFocused = false
            }
        }
        .onChange(of: viewModel.snapshot.chapterIndex) { _, newIndex in
            scrollPosition = newIndex
            crownScrollIndex = Float(newIndex)
        }
    }

    private func claimCrownFocus() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard isActive else { return }
            crownFocused = true
        }
    }
}
