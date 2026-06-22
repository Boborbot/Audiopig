//
//  ImportLibrarySheet.swift
//  Audiopig
//

import SwiftUI

struct ImportLibrarySheet: View {
    @Bindable var viewModel: LibraryImportViewModel
    let onImportFiles: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    importActionsSection
                    backupActionsSection
                    migrationGuideSection
                }
                .padding(DS.Spacing.md)
            }
            .background(DS.Color.canvas)
            .navigationTitle("Import Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.isSheetPresented = false
                    }
                }
            }
        }
        .sheetGlass()
    }

    private var importActionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("From Files")
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(DS.Color.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: DS.Spacing.sm) {
                Button {
                    viewModel.isSheetPresented = false
                    onImportFiles()
                } label: {
                    importRow(
                        title: "Import Files",
                        subtitle: "Pick one or more M4B or MP3 files",
                        systemImage: "doc"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.presentFolderImporter()
                } label: {
                    importRow(
                        title: "Import Folder",
                        subtitle: "Import every audiobook in a folder",
                        systemImage: "folder"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var backupActionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Audiopig Backup")
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(DS.Color.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: DS.Spacing.sm) {
                Button {
                    viewModel.exportLibraryBackup()
                } label: {
                    importRow(
                        title: "Export Library Backup",
                        subtitle: "Save progress and bookmarks to Files",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.presentManifestImporter()
                } label: {
                    importRow(
                        title: "Restore from Backup",
                        subtitle: "Apply progress after importing your audio files",
                        systemImage: "arrow.counterclockwise"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var migrationGuideSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Switching From Another Player")
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(DS.Color.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                guideStep(
                    number: 1,
                    text: "In the Files app, open the folder that contains your audiobook files."
                )
                guideStep(
                    number: 2,
                    text: "Tap Import Folder above and select that folder."
                )
                guideStep(
                    number: 3,
                    text: "Audiopig copies your DRM-free M4B and MP3 files into its library."
                )

                Text("BookPlayer stores processed audio in Files → On My iPhone → BookPlayer → Processed.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.secondary)

                Text("Playback positions from other players are not included. Export an Audiopig backup before switching apps, then restore it after importing your audio files.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.tertiary)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Color.secondarySurface)
            )
        }
    }

    private func importRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(DS.Color.coral)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.listTitle)
                    .foregroundStyle(DS.Color.primary)
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Color.tertiary)
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Color.secondarySurface)
        )
    }

    private func guideStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text("\(number)")
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(DS.Color.coral)
                .frame(width: 20, height: 20)
                .background(Circle().fill(DS.Color.coralSubtle))

            Text(text)
                .font(DS.Typography.listBody)
                .foregroundStyle(DS.Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
