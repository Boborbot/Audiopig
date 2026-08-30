//
//  CoverSearchPastePolicy.swift
//  AudiopigShared
//

import Foundation

public enum CoverSearchPastePolicy {

    /// True when the user returned from a cover search and the pasteboard gained a new image.
    public static func shouldAutoPaste(
        isAwaitingCoverSearchPaste: Bool,
        pasteboardChangeCountAtSearch: Int?,
        currentChangeCount: Int,
        hasImageOnPasteboard: Bool
    ) -> Bool {
        guard isAwaitingCoverSearchPaste,
              let baseline = pasteboardChangeCountAtSearch else { return false }
        return currentChangeCount != baseline && hasImageOnPasteboard
    }

    /// True when the pasteboard changed after search but holds no image (e.g. copied a link).
    public static func shouldEndAwaitingPaste(
        isAwaitingCoverSearchPaste: Bool,
        pasteboardChangeCountAtSearch: Int?,
        currentChangeCount: Int
    ) -> Bool {
        guard isAwaitingCoverSearchPaste,
              let baseline = pasteboardChangeCountAtSearch else { return false }
        return currentChangeCount != baseline
    }
}
