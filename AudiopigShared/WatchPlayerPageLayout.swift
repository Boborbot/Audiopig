//
//  WatchPlayerPageLayout.swift
//  AudiopigShared
//

import Foundation

/// Vertical Watch player pages. Speed and chapters always exist; artwork is Plus-only.
public enum WatchPlayerPageKind: String, Hashable, Sendable {
    case speed
    case media
    case artwork
    case chapters
}

/// Maps artwork-view settings onto the swipe order used by `WatchPlayerPagerView`.
public enum WatchPlayerPageLayout {
    /// Swipe order: speed is always first, chapters always last.
    /// `.add` inserts artwork between speed and the standard controls.
    public static func pages(artworkViewMode: WatchArtworkViewMode) -> [WatchPlayerPageKind] {
        switch artworkViewMode {
        case .off:
            [.speed, .media, .chapters]
        case .replaceStandardControls:
            [.speed, .artwork, .chapters]
        case .add:
            [.speed, .artwork, .media, .chapters]
        }
    }

    /// Page shown when opening the player from the library.
    public static func mainControlsPage(artworkViewMode: WatchArtworkViewMode) -> WatchPlayerPageKind {
        switch artworkViewMode {
        case .off, .add:
            .media
        case .replaceStandardControls:
            .artwork
        }
    }

    /// Keeps the current page if it still exists after an artwork-mode change.
    public static func resolve(
        _ page: WatchPlayerPageKind,
        artworkViewMode: WatchArtworkViewMode
    ) -> WatchPlayerPageKind {
        let pages = pages(artworkViewMode: artworkViewMode)
        if pages.contains(page) { return page }
        return mainControlsPage(artworkViewMode: artworkViewMode)
    }
}

public nonisolated enum WatchPlayerSwipeAction: Equatable, Sendable {
    case none
    case previousPage
    case nextPage
    case exitPlayer
}

public nonisolated enum WatchPlayerSwipeResolver {
    public static let minimumTranslation = 36.0

    public static func action(
        horizontal: Double,
        vertical: Double,
        allowsVerticalPaging: Bool
    ) -> WatchPlayerSwipeAction {
        if abs(horizontal) > abs(vertical) {
            return horizontal >= minimumTranslation ? .exitPlayer : .none
        }

        guard allowsVerticalPaging else { return .none }
        if vertical >= minimumTranslation { return .previousPage }
        if vertical <= -minimumTranslation { return .nextPage }
        return .none
    }
}
