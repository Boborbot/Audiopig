//
//  BookFinishEvent.swift
//  Audiopig
//
//  Snapshot passed to achievement evaluators whenever a book is completed.
//

import Foundation

struct BookFinishEvent: Equatable {
    let audiobookID: UUID
    let title: String
    let author: String
    let totalSeconds: TimeInterval
    let listenedSeconds: TimeInterval
    let chapterCount: Int
    let finishedAt: Date
    let wasManuallyMarked: Bool
}
