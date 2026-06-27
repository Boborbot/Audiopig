//
//  SubtitlesListView.swift
//  Audiopig
//

import SwiftUI

struct SubtitlesListView: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var shareItems: [Any]?
    @State private var isShareSheetPresented = false
    @State private var exportErrorMessage: String?
    @State private var isDeleteTranscriptionConfirmationPresented = false

    var body: some View {
        NavigationStack {
            List {
                transcribeAsYouGoSection
                coverageSection
                wholeBookSection
                exportSection
                deleteTranscriptionSection
                disclaimerSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Subtitles")
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
        .sheet(isPresented: $isShareSheetPresented) {
            if let shareItems {
                ShareActivityView(activityItems: shareItems)
            }
        }
        .alert("Export Failed", isPresented: exportErrorBinding) {
            Button("OK", role: .cancel) { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .alert("Delete Transcription?", isPresented: $isDeleteTranscriptionConfirmationPresented) {
            Button("Delete", role: .destructive) {
                viewModel.deleteSavedTranscription()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all saved subtitle lines for this book from your device. You can transcribe again later.")
        }
    }

    // MARK: - Sections

    private var transcribeAsYouGoSection: some View {
        Section {
            Toggle(isOn: transcribeAsYouGoBinding) {
                Label("Transcribe as you go", systemImage: "captions.bubble")
            }
            .tint(DS.Color.coral)
            .disabled(!viewModel.subtitlesSupported)
        } footer: {
            Text("Automatically transcribe the next ten-minute section when you get within about two minutes of saved subtitles. The captions button animates while transcription runs.")
                .font(DS.Typography.caption)
        }
    }

    private var coverageSection: some View {
        Section {
            if viewModel.hasSavedSubtitles {
                LabeledContent("Saved lines") {
                    Text("\(viewModel.subtitleCoverageSummary.cueCount)")
                        .foregroundStyle(DS.Color.secondary)
                }
                LabeledContent("Book coverage") {
                    Text(coverageLabel)
                        .foregroundStyle(DS.Color.secondary)
                }
                if viewModel.subtitleCoverageSummary.uncoveredWindowCount > 0 {
                    LabeledContent("Sections to fill") {
                        Text("\(viewModel.subtitleCoverageSummary.uncoveredWindowCount)")
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
                LabeledContent("Storage on device") {
                    Text(viewModel.subtitleCoverageSummary.formattedStorageSize)
                        .foregroundStyle(DS.Color.secondary)
                }
            } else {
                Text("No subtitles saved yet. Generate near your position from the player, or transcribe the entire book below.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.secondary)
            }
        } header: {
            Text("Saved Transcription")
        } footer: {
            Text("Subtitles are saved on this device. Transcribed sections are tracked by ten-minute windows — whole-book transcription fills any gaps in partial files.")
                .font(DS.Typography.caption)
        }
    }

    private var wholeBookSection: some View {
        Section {
            switch viewModel.wholeBookJobState {
            case .idle:
                if viewModel.hasUncoveredSubtitleWindows {
                    Button {
                        viewModel.generateSubtitlesWholeBook()
                    } label: {
                        Label("Transcribe Entire Book", systemImage: "text.append")
                    }
                    .disabled(!viewModel.subtitlesSupported)
                } else {
                    Label("Entire book transcribed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(DS.Color.coral)
                }

            case .preparing:
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .tint(DS.Color.coral)
                    Text("Preparing transcription…")
                        .font(DS.Typography.listBody)
                        .foregroundStyle(DS.Color.secondary)
                }

            case .running(let completed, let total, let message):
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.sm) {
                        ProgressView()
                            .tint(DS.Color.coral)
                        Text(message)
                            .font(DS.Typography.listBody)
                            .foregroundStyle(DS.Color.secondary)
                    }
                    ProgressView(value: Double(completed), total: Double(max(total, 1)))
                        .tint(DS.Color.coral)
                    wholeBookControlRow
                }

            case .paused(let completed, let total):
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Paused at section \(completed + 1) of \(total)")
                        .font(DS.Typography.listBody)
                        .foregroundStyle(DS.Color.secondary)
                    ProgressView(value: Double(completed), total: Double(max(total, 1)))
                        .tint(DS.Color.coral)
                    wholeBookControlRow
                }

            case .failed(let message):
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(message)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.secondary)
                    Button("Try Again") {
                        viewModel.generateSubtitlesWholeBook()
                    }
                }
            }
        } header: {
            Text("Entire Book")
        } footer: {
            Text("Runs in the background while you listen or browse. Progress stays here — the player overlay only shows subtitles near you.")
                .font(DS.Typography.caption)
        }
    }

    private var wholeBookControlRow: some View {
        HStack(spacing: DS.Spacing.md) {
            if case .paused = viewModel.wholeBookJobState {
                Button("Resume") {
                    viewModel.resumeWholeBookTranscription()
                }
            } else if case .running = viewModel.wholeBookJobState {
                Button("Pause") {
                    viewModel.pauseWholeBookTranscription()
                }
            }

            Button("Cancel", role: .destructive) {
                viewModel.cancelWholeBookTranscription()
            }
        }
        .font(DS.Typography.caption)
    }

    private var exportSection: some View {
        Section {
            Button {
                export(format: .plainText)
            } label: {
                Label("Export Plain Text", systemImage: "doc.text")
            }
            .disabled(!viewModel.hasSavedSubtitles)

            Button {
                export(format: .srt)
            } label: {
                Label("Export SRT", systemImage: "captions.bubble")
            }
            .disabled(!viewModel.hasSavedSubtitles)
        } header: {
            Text("Export")
        } footer: {
            Text("Exports are saved to On My iPhone › Audiopig › Exported Subtitles.")
                .font(DS.Typography.caption)
        }
    }

    private var deleteTranscriptionSection: some View {
        Section {
            Button("Delete Existing Transcription", role: .destructive) {
                isDeleteTranscriptionConfirmationPresented = true
            }
            .disabled(!viewModel.hasSavedSubtitles)
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text("Subtitles are autogenerated on device and likely contain occasional mistakes.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
        }
        .listRowSeparator(.hidden)
    }

    // MARK: - Helpers

    private var transcribeAsYouGoBinding: Binding<Bool> {
        Binding(
            get: { viewModel.transcribeAsYouGoEnabled },
            set: { viewModel.transcribeAsYouGoEnabled = $0 }
        )
    }

    private var coverageLabel: String {
        let fraction = viewModel.subtitleCoverageSummary.coverageFraction
        let percent = Int((fraction * 100).rounded())
        return "\(percent)%"
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )
    }

    private func export(format: SubtitleExportFormat) {
        do {
            guard let url = try viewModel.exportSubtitles(format: format) else { return }
            shareItems = [url]
            isShareSheetPresented = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}
