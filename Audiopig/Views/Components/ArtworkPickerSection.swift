//
//  ArtworkPickerSection.swift
//  Audiopig
//
//  Shared artwork preview + source picker used by edit sheets.
//  Uses confirmationDialog instead of Menu so taps register reliably inside Form rows.
//

import SwiftUI

struct ArtworkPickerSection<Placeholder: View>: View {

    @Binding var draftArtwork: UIImage?
    @Binding var isPhotoPickerPresented: Bool
    @Binding var isCameraPresented: Bool
    @Binding var isFileImporterPresented: Bool

    let hasClipboardImage: Bool
    let onPasteFromClipboard: () -> Void
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var isSourcePickerPresented = false

    var body: some View {
        Section {
            HStack(spacing: DS.Spacing.md) {
                artworkPreview
                    .frame(width: 100, height: 100)
                    .listCoverArtClip()

                Button("Change Artwork") {
                    isSourcePickerPresented = true
                }
                .font(.callout)
                .foregroundStyle(DS.Color.coral)
                .buttonStyle(.borderless)
            }
            .padding(.vertical, DS.Spacing.xs)
        } header: {
            Text("Artwork")
        }
        .confirmationDialog("Change Artwork", isPresented: $isSourcePickerPresented, titleVisibility: .visible) {
            Button("Photo Library") { isPhotoPickerPresented = true }
            Button("Camera") { isCameraPresented = true }
            Button("Choose File") { isFileImporterPresented = true }
            if hasClipboardImage {
                Button("Paste from Clipboard") { onPasteFromClipboard() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var artworkPreview: some View {
        if let img = draftArtwork {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholder()
        }
    }
}
