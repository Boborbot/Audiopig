//
//  WatchTransferStaging.swift
//  AudiopigShared
//

import Foundation

public enum WatchTransferStaging {
    private static let outgoingRootName = "WatchOutgoingTransfers"

    public static func stageOutgoingFile(
        bookID: UUID,
        sourceURL: URL,
        fileExtension: String,
        fileManager: FileManager = .default
    ) throws -> URL {
        let bookDir = try outgoingRootURL(fileManager: fileManager).appendingPathComponent(bookID.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: bookDir.path) {
            try fileManager.removeItem(at: bookDir)
        }
        try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)
        let destination = bookDir.appendingPathComponent("audio.\(fileExtension)")
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    public static func removeOutgoingStage(bookID: UUID, fileManager: FileManager = .default) {
        guard let root = try? outgoingRootURL(fileManager: fileManager) else { return }
        let bookDir = root.appendingPathComponent(bookID.uuidString, isDirectory: true)
        try? fileManager.removeItem(at: bookDir)
    }

    /// Copies an incoming `WCSession` file before the delegate returns (the system deletes the original immediately after).
    public static func copyIncomingFile(from sourceURL: URL, fileManager: FileManager = .default) throws -> URL {
        let destination = fileManager.temporaryDirectory
            .appendingPathComponent("watch-incoming-\(UUID().uuidString)")
            .appendingPathExtension(sourceURL.pathExtension)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    private static func outgoingRootURL(fileManager: FileManager) throws -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = appSupport.appendingPathComponent(outgoingRootName, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
