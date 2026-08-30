//
//  BookmarkEditView.swift
//  Audiopig
//

import SwiftUI

struct BookmarkEditView: View {
    let viewModel: PlayerViewModel
    let bookmark: Bookmark

    @Environment(\.dismiss) private var dismiss

    @State private var draftTitle: String
    @State private var draftNote: String
    @State private var draftTimestamp: TimeInterval
    @State private var dictation = SpeechDictationService()
    @State private var activeDictationField: DictationField?
    @State private var dictationBaseText = ""
    @State private var dictationError: SpeechDictationError?

    private var maxTimestamp: TimeInterval {
        max(bookmark.audiobook?.duration ?? 0, bookmark.timestamp)
    }

    init(viewModel: PlayerViewModel, bookmark: Bookmark) {
        self.viewModel = viewModel
        self.bookmark = bookmark
        _draftTitle = State(initialValue: bookmark.title)
        _draftNote = State(initialValue: bookmark.note)
        _draftTimestamp = State(initialValue: bookmark.timestamp)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    dictationTextField(
                        placeholder: "Name (optional)",
                        text: $draftTitle,
                        field: .name,
                        axis: .horizontal
                    )
                } header: {
                    Text("Name")
                }

                Section {
                    dictationTextField(
                        placeholder: "Note (optional)",
                        text: $draftNote,
                        field: .note,
                        axis: .vertical
                    )
                } header: {
                    Text("Note")
                }

                Section {
                    BookmarkTimestampRolodexPicker(
                        timestamp: $draftTimestamp,
                        maxTimestamp: maxTimestamp
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Timestamp")
                }
            }
            .navigationTitle("Edit Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Color.coral)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.coral)
                }
            }
        }
        .sheetGlass()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            stopDictation()
        }
        .alert(
            "Dictation Unavailable",
            isPresented: Binding(
                get: { dictationError != nil },
                set: { if !$0 { dictationError = nil } }
            ),
            presenting: dictationError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Dictation Field

    @ViewBuilder
    private func dictationTextField(
        placeholder: String,
        text: Binding<String>,
        field: DictationField,
        axis: Axis
    ) -> some View {
        HStack(alignment: axis == .vertical ? .top : .center, spacing: DS.Spacing.sm) {
            Group {
                if axis == .vertical {
                    TextField(placeholder, text: text, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .autocorrectionDisabled(false)

            SpeechDictationMicButton(
                isRecording: activeDictationField == field,
                accessibilityLabel: field.micAccessibilityLabel
            ) {
                toggleDictation(for: field)
            }
        }
    }

    // MARK: - Dictation

    private func toggleDictation(for field: DictationField) {
        if activeDictationField == field {
            stopDictation()
            return
        }

        stopDictation()
        activeDictationField = field
        dictationBaseText = field == .name ? draftTitle : draftNote

        Task {
            do {
                try await dictation.start { transcript in
                    applyDictationTranscript(transcript, to: field)
                }
            } catch let error as SpeechDictationError {
                activeDictationField = nil
                dictationError = error
            } catch {
                activeDictationField = nil
                dictationError = .audioEngineFailed
            }
        }
    }

    private func applyDictationTranscript(_ transcript: String, to field: DictationField) {
        guard activeDictationField == field else { return }
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return }

        let base = dictationBaseText.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = base.isEmpty ? trimmedTranscript : "\(base) \(trimmedTranscript)"

        switch field {
        case .name:
            draftTitle = combined
        case .note:
            draftNote = combined
        }
    }

    private func stopDictation() {
        dictation.stop()
        activeDictationField = nil
        dictationBaseText = ""
    }

    // MARK: - Save

    private func save() {
        stopDictation()
        viewModel.updateBookmark(
            bookmark,
            title: draftTitle.trimmingCharacters(in: .whitespaces),
            note: draftNote.trimmingCharacters(in: .whitespaces),
            timestamp: draftTimestamp
        )
        dismiss()
    }
}

// MARK: - Dictation Field

private enum DictationField {
    case name
    case note

    var micAccessibilityLabel: String {
        switch self {
        case .name: return "Dictate bookmark name"
        case .note: return "Dictate bookmark note"
        }
    }
}
