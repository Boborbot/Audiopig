//
//  WholeBookTranscriptionQueueServiceProtocol.swift
//  Audiopig
//

import Foundation

enum WholeBookEnqueueResult: Sendable, Equatable {
    case enqueued
    case alreadyInQueue
    case alreadyComplete
    case unsupported
    case paywallRequired
}

@MainActor
protocol WholeBookTranscriptionQueueServiceProtocol: AnyObject {
    var revision: UInt64 { get }
    var hasQueueUI: Bool { get }
    var hasActiveJob: Bool { get }
    var queueCount: Int { get }

    func allSnapshots() -> [WholeBookQueueItemSnapshot]
    func snapshot(for audiobookID: UUID?) -> WholeBookQueueItemSnapshot?
    func queuePosition(for audiobookID: UUID) -> Int?

    @discardableResult
    func enqueue(audiobookID: UUID) -> WholeBookEnqueueResult
    func cancel(audiobookID: UUID)
    func pause(audiobookID: UUID)
    func resume(audiobookID: UUID)
    func moveEntry(from source: IndexSet, to destination: Int)
    func restoreOnLaunch()
}
