//
//  CoverArtSearch.swift
//  AudiopigShared
//

import Foundation

public enum CoverArtSearch {

    /// Google Images search for audiobook cover art: `"{title} audiobook"`.
    public static func googleImagesURL(title: String) -> URL? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let query = "\(trimmed) audiobook"
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "tbm", value: "isch"),
            URLQueryItem(name: "q", value: query),
        ]
        return components.url
    }
}
