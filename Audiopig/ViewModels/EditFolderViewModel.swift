//
//  EditFolderViewModel.swift
//  Audiopig
//

import Observation
import UIKit

@MainActor
@Observable
final class EditFolderViewModel {

    // MARK: - Draft State

    var draftTitle: String
    var draftArtwork: UIImage?

    // MARK: - Artwork Picker State

    var isPhotoPickerPresented: Bool = false
    var isCameraPresented: Bool = false
    var isFileImporterPresented: Bool = false

    var hasClipboardImage: Bool {
        UIPasteboard.general.hasImages
    }

    // MARK: - Validation

    var canSave: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Init

    init(folder: Folder) {
        self.draftTitle = folder.title
        self.draftArtwork = CoverArtCache.shared.image(for: folder)
    }

    // MARK: - Artwork Sources

    func pasteFromClipboard() {
        guard let image = UIPasteboard.general.image else { return }
        draftArtwork = image
    }

    func handleFileImport(result: Result<URL, Error>) {
        guard case .success(let url) = result,
              url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return }
        draftArtwork = image
    }

    // MARK: - Save

    func save(to folder: Folder) {
        folder.title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let image = draftArtwork,
           let jpeg = image.jpegData(compressionQuality: 0.85) {
            folder.coverArtwork = jpeg
            CoverArtCache.shared.invalidate(for: folder.id)
        }
    }
}
