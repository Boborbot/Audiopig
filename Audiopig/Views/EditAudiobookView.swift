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
        @Bindable var vm = vm

        NavigationStack {
            Form {
                ArtworkPickerSection(
                    draftArtwork: $vm.draftArtwork,
                    isPhotoPickerPresented: $vm.isPhotoPickerPresented,
                    isCameraPresented: $vm.isCameraPresented,
                    isFileImporterPresented: $vm.isFileImporterPresented,
                    hasClipboardImage: vm.hasClipboardImage,
                    onPasteFromClipboard: { vm.pasteFromClipboard() }
                ) {
                    ZStack {
                        audiobook.placeholderColor.opacity(0.75)
                        Image(systemName: "headphones")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

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
                    photoPickerItem = nil
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
}
