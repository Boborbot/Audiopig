//
//  WatchBookTransferStatus.swift
//  Audiopig
//

import Foundation

enum WatchBookTransferStatus: Equatable {
    case unavailable
    case notOnWatch
    case transferring(progress: WatchTransferProgress)
    case onWatch
    case failed(String)
}
