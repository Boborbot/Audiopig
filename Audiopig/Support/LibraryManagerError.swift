//
//  LibraryManagerError.swift
//  Audiopig
//

import Foundation

enum LibraryManagerError: Error, Equatable, Sendable {
    case unsupportedFileFormat
    case fileNotFound
    case metadataExtractionFailed
    case fileSystemOperationFailed
    case importFailed
    case insufficientAudiobooksForMerge
    case mergeFailed
}
