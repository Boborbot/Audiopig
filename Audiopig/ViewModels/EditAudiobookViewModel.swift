//
//  EditAudiobookViewModel.swift
//  Audiopig
//

import Observation
import UIKit

@MainActor
@Observable
final class EditAudiobookViewModel {

    // MARK: - Draft State

    var draftTitle: String
    var draftAuthor: String
    var draftArtwork: UIImage?

    // MARK: - Artwork Picker State

    var isPhotoPickerPresented: Bool = false
    var isCameraPresented: Bool = false
    var isFileImporterPresented: Bool = false
    var hasClipboardImage: Bool = false
    var coverArtworkWasAutoPasted: Bool = false

    private var isAwaitingCoverSearchPaste = false
    private var pasteboardChangeCountAtSearch: Int?

    // MARK: - Validation

    var canSave: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Init

    init(audiobook: Audiobook) {
        self.draftTitle = audiobook.title
        self.draftAuthor = audiobook.author
        self.draftArtwork = CoverArtCache.shared.image(for: audiobook)
        refreshClipboardState()
    }

    // MARK: - Artwork Sources

    func refreshClipboardState() {
        hasClipboardImage = UIPasteboard.general.hasImages
    }

    func openCoverSearch() {
        pasteboardChangeCountAtSearch = UIPasteboard.general.changeCount
        isAwaitingCoverSearchPaste = true
        coverArtworkWasAutoPasted = false

        guard let url = CoverArtSearch.googleImagesURL(title: draftTitle) else {
            clearCoverSearchPasteSession()
            return
        }
        ExternalBrowser.open(url)
    }

    func handleReturnToForeground() {
        refreshClipboardState()
        tryAutoPasteAfterCoverSearchReturn()
    }

    func tryAutoPasteAfterCoverSearchReturn() {
        let pasteboard = UIPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        if CoverSearchPastePolicy.shouldAutoPaste(
            isAwaitingCoverSearchPaste: isAwaitingCoverSearchPaste,
            pasteboardChangeCountAtSearch: pasteboardChangeCountAtSearch,
            currentChangeCount: currentChangeCount,
            hasImageOnPasteboard: pasteboard.hasImages
        ), let image = pasteboard.image {
            draftArtwork = image
            coverArtworkWasAutoPasted = true
            clearCoverSearchPasteSession()
            return
        }

        if CoverSearchPastePolicy.shouldEndAwaitingPaste(
            isAwaitingCoverSearchPaste: isAwaitingCoverSearchPaste,
            pasteboardChangeCountAtSearch: pasteboardChangeCountAtSearch,
            currentChangeCount: currentChangeCount
        ) {
            clearCoverSearchPasteSession()
        }
    }

    func pasteFromClipboard() {
        guard let image = UIPasteboard.general.image else { return }
        draftArtwork = image
        coverArtworkWasAutoPasted = false
        clearCoverSearchPasteSession()
    }

    func copyArtworkToClipboard() {
        guard let image = draftArtwork else { return }
        UIPasteboard.general.image = image
    }

    func removeArtwork() {
        draftArtwork = nil
        coverArtworkWasAutoPasted = false
        clearCoverSearchPasteSession()
    }

    func handleFileImport(result: Result<URL, Error>) {
        guard case .success(let url) = result,
              url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return }
        applyArtworkFromSource(image)
    }

    func applyArtworkFromSource(_ image: UIImage) {
        draftArtwork = image
        coverArtworkWasAutoPasted = false
        clearCoverSearchPasteSession()
    }

    // MARK: - Save

    func save(to audiobook: Audiobook) {
        audiobook.title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        audiobook.author = draftAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        if let image = draftArtwork,
           let jpeg = image.jpegData(compressionQuality: 0.85) {
            audiobook.coverArtwork = jpeg
        } else {
            audiobook.coverArtwork = nil
        }
        CoverArtCache.shared.invalidate(for: audiobook.id)
    }

    private func clearCoverSearchPasteSession() {
        isAwaitingCoverSearchPaste = false
        pasteboardChangeCountAtSearch = nil
    }
}
