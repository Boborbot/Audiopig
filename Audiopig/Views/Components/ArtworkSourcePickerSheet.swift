//
//  ArtworkSourcePickerSheet.swift
//  Audiopig
//
//  Artwork source list with icons. Replaces confirmationDialog for reliable Form taps.
//

import SwiftUI
import UIKit

struct ArtworkSourcePickerSheet: View {

    let showsCoverSearch: Bool
    let onPhotoLibrary: () -> Void
    let onCamera: () -> Void
    let onChooseFile: () -> Void
    let onPasteFromClipboard: () -> Void
    let onSearchForCover: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hasClipboardImage = false

    var body: some View {
        NavigationStack {
            List {
                sourceRow(
                    icon: "photo.on.rectangle",
                    title: "Photo Library",
                    action: onPhotoLibrary
                )
                sourceRow(
                    icon: "camera",
                    title: "Camera",
                    action: onCamera
                )
                sourceRow(
                    icon: "folder",
                    title: "Choose File",
                    action: onChooseFile
                )
                sourceRow(
                    icon: "doc.on.clipboard",
                    title: "Paste from Clipboard",
                    action: onPasteFromClipboard,
                    isEnabled: hasClipboardImage
                )
                if showsCoverSearch {
                    sourceRow(
                        icon: "safari",
                        title: "Search for Cover",
                        action: onSearchForCover
                    )
                }
            }
            .navigationTitle("Change Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Color.coral)
                }
            }
            .onAppear {
                hasClipboardImage = UIPasteboard.general.hasImages
            }
        }
        .presentationDetents([showsCoverSearch ? .height(340) : .height(280)])
        .presentationDragIndicator(.visible)
    }

    private func sourceRow(
        icon: String,
        title: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true
    ) -> some View {
        Button {
            dismiss()
            action()
        } label: {
            Label {
                Text(title)
                    .foregroundStyle(isEnabled ? DS.Color.primary : DS.Color.tertiary)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(isEnabled ? DS.Color.coral : DS.Color.tertiary)
            }
        }
        .disabled(!isEnabled)
    }
}
