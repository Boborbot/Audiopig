//
//  WatchImportInstructionsView.swift
//  AudiopigWatch
//

import SwiftUI

struct WatchImportInstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WDS.Spacing.md) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.title2)
                    .foregroundStyle(WDS.Color.coral)

                Text("Send books from iPhone")
                    .font(WDS.Typography.title)

                instructionRow(number: 1, text: "Long-press a book on iPhone → Send to Watch")
                instructionRow(number: 2, text: "Or Settings → Watch Library")
            }
            .padding()
        }
        .navigationTitle("Add Books")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: WDS.Spacing.sm) {
            Text("\(number).")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(WDS.Color.coral)
            Text(text)
                .font(.caption)
        }
    }
}
