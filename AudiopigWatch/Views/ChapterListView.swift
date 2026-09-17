//
//  ChapterListView.swift
//  AudiopigWatch
//

import SwiftUI

struct ChapterListView: View {
    @ObservedObject var viewModel: WatchPlayerViewModel
    var onChapterSelected: () -> Void

    init(viewModel: WatchPlayerViewModel, onChapterSelected: @escaping () -> Void) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.onChapterSelected = onChapterSelected
    }

    @State private var scrollPosition: Int?

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
            }
        }
        .onAppear {
            scrollPosition = viewModel.snapshot.chapterIndex
            Task {
                await viewModel.requestChaptersIfNeeded()
            }
        }
        .onChange(of: viewModel.snapshot.chapterIndex) { _, newIndex in
            scrollPosition = newIndex
        }
    }
}
