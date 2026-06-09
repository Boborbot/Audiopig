//
//  AudiobookImportMetadata.swift
//  Audiopig
//

import Foundation

struct ChapterImportMetadata: Equatable, Sendable {
    let title: String
    let duration: TimeInterval
    let startTime: TimeInterval
    let orderIndex: Int
    let fileURL: URL
}

struct AudiobookImportMetadata: Equatable, Sendable {
    let title: String
    let author: String
    let duration: TimeInterval
    let coverArtwork: Data?
    let fileURL: URL
    let chapters: [ChapterImportMetadata]
}
