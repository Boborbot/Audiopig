//
//  EditAudiobookView.swift
//  Audiopig
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct EditAudiobookView: View {

    let audiobook: Audiobook
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vm: EditAudiobookViewModel
    @State private var photoPickerItem: PhotosPickerItem?

    init(audiobook: Audiobook, onSave: @escaping () -> Void) {
        self.audiobook = audiobook
        self.onSave = onSave
        _vm = State(initialValue: EditAudiobookViewModel(audiobook: audiobook))
    }

    var body: some View {
        NavigationStack {
            Form {
                artworkSection
                metadataSection
            }
            .navigationTitle("Edit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Color.coral)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.save(to: audiobook)
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(vm.canSave ? DS.Color.coral : DS.Color.secondary)
                    .disabled(!vm.canSave)
                }
            }
            .photosPicker(
                isPresented: $vm.isPhotoPickerPresented,
                selection: $photoPickerItem,
                matching: .images
            )
            .onChange(of: photoPickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        vm.draftArtwork = image
                    }
                }
            }
            .sheet(isPresented: $vm.isCameraPresented) {
                CameraPickerView { image in
                    vm.draftArtwork = image
                }
                .ignoresSafeArea()
            }
            .fileImporter(
                isPresented: $vm.isFileImporterPresented,
                allowedContentTypes: [.image, .jpeg, .png, .heic],
                allowsMultipleSelection: false
            ) { result in
                vm.handleFileImport(result: result.map { $0[0] })
            }
        }
    }

    // MARK: - Sections

    private var artworkSection: some View {
        Section {
            HStack(spacing: DS.Spacing.md) {
                artworkPreview
                    .frame(width: 100, height: 100)
                    .listCoverArtClip()

                changeArtworkMenu
            }
            .padding(.vertical, DS.Spacing.xs)
        } header: {
            Text("Artwork")
        }
    }

    private var metadataSection: some View {
        Section {
            LabeledContent("Name") {
                TextField("Book title", text: $vm.draftTitle)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Author") {
                TextField("Author name", text: $vm.draftAuthor)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Details")
        }
    }

    // MARK: - Artwork Components

    @ViewBuilder
    private var artworkPreview: some View {
        if let img = vm.draftArtwork {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                audiobook.placeholderColor.opacity(0.75)
                Image(systemName: "headphones")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var changeArtworkMenu: some View {
        Menu {
            Button {
                vm.isPhotoPickerPresented = true
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }

            Button {
                vm.isCameraPresented = true
            } label: {
                Label("Camera", systemImage: "camera")
            }

            Button {
                vm.isFileImporterPresented = true
            } label: {
                Label("Choose File", systemImage: "doc")
            }

            if vm.hasClipboardImage {
                Button {
                    vm.pasteFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                }
            }
        } label: {
            Text("Change Artwork")
                .font(.callout)
                .foregroundStyle(DS.Color.coral)
        }
    }
}
