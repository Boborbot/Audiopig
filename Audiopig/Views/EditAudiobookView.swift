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
    @Environment(\.scenePhase) private var scenePhase
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
                    onPasteFromClipboard: { vm.pasteFromClipboard() },
                    onCopyArtwork: { vm.copyArtworkToClipboard() },
                    onRemoveArtwork: { vm.removeArtwork() },
                    showsPastedFromClipboardNotice: vm.coverArtworkWasAutoPasted,
                    onSearchForCover: { vm.openCoverSearch() }
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
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.save(to: audiobook)
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(vm.canSave ? Color.green : DS.Color.secondary)
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
                        vm.applyArtworkFromSource(image)
                    }
                    photoPickerItem = nil
                }
            }
            .sheet(isPresented: $vm.isCameraPresented) {
                CameraPickerView { image in
                    vm.applyArtworkFromSource(image)
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
            .onAppear {
                vm.refreshClipboardState()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                vm.handleReturnToForeground()
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
