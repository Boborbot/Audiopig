//
//  WatchLocalBooksPayload.swift
//  AudiopigShared
//

import Foundation

public struct WatchLocalBooksPayload: Codable, Sendable, Equatable {
    public let books: [WatchBookSummary]
    public let usedBytes: Int64
    public let budgetBytes: Int64

    public init(books: [WatchBookSummary], usedBytes: Int64, budgetBytes: Int64) {
        self.books = books
        self.usedBytes = usedBytes
        self.budgetBytes = budgetBytes
    }
}
