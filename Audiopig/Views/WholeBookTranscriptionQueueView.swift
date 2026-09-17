//
//  WholeBookTranscriptionQueueView.swift
//  Audiopig
//

import SwiftUI

struct WholeBookTranscriptionQueueView: View {
    let viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.transcriptionQueueSnapshots) { item in
                    queueRow(item)
                }
                .onMove(perform: viewModel.moveTranscriptionQueueEntry)
                .onDelete { indexSet in
                    for index in indexSet {
                        let snapshots = viewModel.transcriptionQueueSnapshots
                        guard snapshots.indices.contains(index) else { continue }
                        viewModel.cancelTranscriptionQueueItem(audiobookID: snapshots[index].audiobookID)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .navigationTitle("Transcription Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DS.Color.coral)
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                        .foregroundStyle(DS.Color.coral)
                }
            }
        }
        .sheetGlass()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func queueRow(_ item: WholeBookQueueItemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(DS.Typography.listTitle)
                        .foregroundStyle(DS.Color.primary)
                        .lineLimit(1)
                    Text(item.author)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: DS.Spacing.sm)
                Text("\(item.coveragePercent)%")
                    .font(DS.Typography.listBody.monospacedDigit())
                    .foregroundStyle(DS.Color.coral)
            }

            HStack {
                Text(statusLabel(for: item))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.secondary)
                Spacer()
                if item.status == .running || item.status == .paused {
                    Text("Section \(item.completedWindows + 1) of \(max(item.totalWindows, 1))")
                        .font(DS.Typography.caption.monospacedDigit())
                        .foregroundStyle(DS.Color.tertiary)
                }
            }

            SubtitleCoverageTimelineBar(timeline: item.coverageTimeline)

            if item.status == .running || item.status == .paused || item.status == .failed {
                HStack(spacing: DS.Spacing.md) {
                    if item.status == .paused || item.status == .failed {
                        Button("Resume") {
                            viewModel.resumeTranscriptionQueueItem(audiobookID: item.audiobookID)
                        }
                    } else if item.status == .running {
                        Button("Pause") {
                            viewModel.pauseTranscriptionQueueItem(audiobookID: item.audiobookID)
                        }
                    }

                    Button("Cancel", role: .destructive) {
                        viewModel.cancelTranscriptionQueueItem(audiobookID: item.audiobookID)
                    }
                }
                .font(DS.Typography.caption)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .moveDisabled(item.status == .running)
    }

    private func statusLabel(for item: WholeBookQueueItemSnapshot) -> String {
        switch item.status {
        case .queued:
            return "Queued (#\(item.queuePosition))"
        case .running:
            if item.isPreparing {
                return "Preparing…"
            }
            return item.progressMessage ?? "Transcribing…"
        case .paused:
            return "Paused"
        case .failed:
            return item.failureMessage ?? "Failed"
        }
    }
}
