//
//  CoverArtCache.swift
//  Audiopig
//
//  Decodes and caches cover art UIImages by audiobook UUID so views never
//  repeat the expensive JPEG/PNG decode across re-renders or ticks.
//

import UIKit

final class CoverArtCache {

    static let shared = CoverArtCache()

    private let cache = NSCache<NSUUID, UIImage>()

    private init() {
        cache.countLimit = 100
    }

    func image(for audiobook: Audiobook) -> UIImage? {
        let key = audiobook.id as NSUUID
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = audiobook.coverArtwork,
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func invalidate(for id: UUID) {
        cache.removeObject(forKey: id as NSUUID)
    }
}
