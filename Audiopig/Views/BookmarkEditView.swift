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
    @State private var draftTimestamp: String
    @State private var timestampError: String? = nil

    init(viewModel: PlayerViewModel, bookmark: Bookmark) {
        self.viewModel = viewModel
        self.bookmark = bookmark
        _draftTitle = State(initialValue: bookmark.title)
        _draftNote  = State(initialValue: bookmark.note)
        _draftTimestamp = State(initialValue: PlayerViewModel.formatTime(bookmark.timestamp))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (optional)", text: $draftTitle)
                        .autocorrectionDisabled(false)
                } header: {
                    Text("Name")
                }

                Section {
                    TextField("Note (optional)", text: $draftNote, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled(false)
                } header: {
                    Text("Note")
                }

                Section {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        TextField("0:00", text: $draftTimestamp)
                            .keyboardType(.asciiCapable)
                            .autocorrectionDisabled()
                            .fontDesign(.monospaced)
                            .onChange(of: draftTimestamp) {
                                timestampError = nil
                            }
                        if let error = timestampError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Timestamp")
                } footer: {
                    Text("Format: H:MM:SS or M:SS")
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
    }

    // MARK: - Save

    private func save() {
        guard let parsed = parseTimestamp(draftTimestamp) else {
            timestampError = "Use H:MM:SS or M:SS format (e.g. 1:23:45 or 4:32)"
            return
        }
        viewModel.updateBookmark(
            bookmark,
            title: draftTitle.trimmingCharacters(in: .whitespaces),
            note: draftNote.trimmingCharacters(in: .whitespaces),
            timestamp: parsed
        )
        dismiss()
    }

    // MARK: - Timestamp Parsing

    /// Parses "H:MM:SS" or "M:SS" (also "MM:SS", "H:M:S" etc.) into seconds.
    /// Returns nil if the format is invalid or any component is out of range.
    private func parseTimestamp(_ raw: String) -> TimeInterval? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
            .map { String($0) }

        switch parts.count {
        case 2:
            guard let m = Int(parts[0]), let s = Int(parts[1]),
                  m >= 0, s >= 0, s < 60 else { return nil }
            return TimeInterval(m * 60 + s)
        case 3:
            guard let h = Int(parts[0]), let m = Int(parts[1]), let s = Int(parts[2]),
                  h >= 0, m >= 0, m < 60, s >= 0, s < 60 else { return nil }
            return TimeInterval(h * 3600 + m * 60 + s)
        default:
            return nil
        }
    }
}
