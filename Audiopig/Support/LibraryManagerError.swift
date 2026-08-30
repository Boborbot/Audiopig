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
    case diskFull
    case insufficientAudiobooksForMerge
    case mergeFailed
}

extension LibraryManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupportedFileFormat:
            return "That file type isn’t supported."
        case .fileNotFound:
            return "The audio file could not be found."
        case .metadataExtractionFailed:
            return "Could not read that audio file."
        case .fileSystemOperationFailed:
            return "Could not copy or remove the audio file."
        case .importFailed:
            return "Could not save the book to your library."
        case .diskFull:
            return "There isn’t enough storage to import."
        case .insufficientAudiobooksForMerge:
            return "Select at least two books to combine."
        case .mergeFailed:
            return "Could not combine those books."
        }
    }
}
