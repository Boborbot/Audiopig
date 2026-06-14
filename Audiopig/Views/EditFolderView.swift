//
//  EditFolderView.swift
//  Audiopig
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct EditFolderView: View {

    let folder: Folder
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vm: EditFolderViewModel
    @State private var photoPickerItem: PhotosPickerItem?

    init(folder: Folder, onSave: @escaping () -> Void) {
        self.folder = folder
        self.onSave = onSave
        _vm = State(initialValue: EditFolderViewModel(folder: folder))
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
                        DS.Color.coral.opacity(0.15)
                        Image(systemName: "folder.fill")
                            .font(.largeTitle)
                            .foregroundStyle(DS.Color.coral)
                    }
                }

                metadataSection
            }
            .navigationTitle("Edit Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Color.coral)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.save(to: folder)
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
            LabeledContent("Title") {
                TextField("Folder title", text: $vm.draftTitle)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Details")
        }
    }
}
