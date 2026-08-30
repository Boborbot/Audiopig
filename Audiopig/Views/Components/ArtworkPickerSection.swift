//
//  ArtworkPickerSection.swift
//  Audiopig
//
//  Shared artwork preview + source picker used by edit sheets.
//

import SwiftUI

struct ArtworkPickerSection<Placeholder: View>: View {

    @Binding var draftArtwork: UIImage?
    @Binding var isPhotoPickerPresented: Bool
    @Binding var isCameraPresented: Bool
    @Binding var isFileImporterPresented: Bool

    let onPasteFromClipboard: () -> Void
    let onCopyArtwork: () -> Void
    let onRemoveArtwork: () -> Void
    var showsPastedFromClipboardNotice: Bool = false
    var onSearchForCover: (() -> Void)? = nil
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var isSourcePickerPresented = false
    @State private var isRemoveArtworkConfirmationPresented = false
    @State private var containerWidth: CGFloat = 0

    @Environment(\.colorScheme) private var colorScheme

    private var showsCoverSearch: Bool { onSearchForCover != nil }

    private var artworkSize: CGSize {
        let width = containerWidth > 0 ? containerWidth : UIScreen.main.bounds.width
        return DS.Layout.playerPortraitArtworkSize(
            containerSize: CGSize(width: width, height: UIScreen.main.bounds.height)
        )
    }

    private var sectionHeight: CGFloat {
        var height = artworkSize.height + DS.Spacing.lg + DS.Layout.artworkActionButtonSize + DS.Spacing.xs + 14 + DS.Spacing.md
        if showsPastedFromClipboardNotice {
            height += DS.Spacing.lg
        }
        return height
    }

    var body: some View {
        Section {
            GeometryReader { geometry in
                VStack(spacing: DS.Spacing.md) {
                    artworkHero(size: artworkSize)

                    HStack(spacing: DS.Spacing.lg) {
                        artworkActionButton(
                            icon: "pencil",
                            label: "Edit",
                            isEnabled: true,
                            iconStyle: .coral
                        ) {
                            isSourcePickerPresented = true
                        }

                        artworkActionButton(
                            icon: "doc.on.doc",
                            label: "Copy",
                            isEnabled: draftArtwork != nil,
                            iconStyle: .neutral,
                            action: onCopyArtwork
                        )

                        artworkActionButton(
                            icon: "trash",
                            label: "Remove",
                            isEnabled: draftArtwork != nil,
                            iconStyle: .destructive
                        ) {
                            isRemoveArtworkConfirmationPresented = true
                        }
                    }

                    if showsPastedFromClipboardNotice {
                        Text("Pasted from clipboard")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .onAppear {
                    containerWidth = geometry.size.width
                }
                .onChange(of: geometry.size.width) { _, width in
                    containerWidth = width
                }
            }
            .frame(height: sectionHeight)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .sheet(isPresented: $isSourcePickerPresented) {
            ArtworkSourcePickerSheet(
                showsCoverSearch: showsCoverSearch,
                onPhotoLibrary: { isPhotoPickerPresented = true },
                onCamera: { isCameraPresented = true },
                onChooseFile: { isFileImporterPresented = true },
                onPasteFromClipboard: onPasteFromClipboard,
                onSearchForCover: { onSearchForCover?() }
            )
        }
        .confirmationDialog(
            "Remove Artwork?",
            isPresented: $isRemoveArtworkConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                onRemoveArtwork()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The cover will be cleared when you save.")
        }
    }

    @ViewBuilder
    private func artworkHero(size: CGSize) -> some View {
        Group {
            if let image = draftArtwork {
                PlayerCoverArt(
                    image: image,
                    containerWidth: size.width,
                    containerHeight: size.height
                )
            } else {
                placeholder()
                    .frame(width: size.width, height: size.height)
                    .playerCoverArtClip()
                    .applyShadows(DS.Shadow.coverArt)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private enum ArtworkActionIconStyle {
        case coral
        case neutral
        case destructive
    }

    private func artworkActionButton(
        icon: String,
        label: String,
        isEnabled: Bool,
        iconStyle: ArtworkActionIconStyle,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(iconForeground(isEnabled: isEnabled, style: iconStyle))
                    .frame(width: DS.Layout.artworkActionButtonSize, height: DS.Layout.artworkActionButtonSize)
                    .background(
                        Circle()
                            .fill(DS.Color.secondarySurface)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(DS.Color.separator.opacity(0.5), lineWidth: 0.5)
                    )

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isEnabled ? DS.Color.secondary : DS.Color.tertiary)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private func iconForeground(isEnabled: Bool, style: ArtworkActionIconStyle) -> Color {
        guard isEnabled else { return DS.Color.tertiary }
        switch style {
        case .coral: return DS.Color.coral
        case .neutral: return colorScheme == .dark ? .white : DS.Color.primary
        case .destructive: return .red
        }
    }
}
