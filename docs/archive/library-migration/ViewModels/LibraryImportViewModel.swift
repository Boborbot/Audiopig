//
//  LibraryImportViewModel.swift
//  Audiopig
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class LibraryImportViewModel {
    private(set) var isImporting = false
    private(set) var lastResult: LibraryImportResult?
    private(set) var lastBackupApplyResult: LibraryBackupApplyResult?
    private(set) var lastExportedBackupURL: URL?
    private(set) var errorMessage: String?

    var isSheetPresented = false
    var isFolderImporterPresented = false
    var isManifestImporterPresented = false
    var isSummaryPresented = false
    var isBackupSummaryPresented = false
    var isExportSuccessPresented = false

    var onLibraryChanged: () -> Void = { }

    private let libraryImportService: any LibraryImportServiceProtocol
    private let libraryBackupService: any LibraryBackupServiceProtocol
    private let modelContext: ModelContext

    init(
        libraryImportService: any LibraryImportServiceProtocol,
        libraryBackupService: any LibraryBackupServiceProtocol,
        modelContext: ModelContext,
        onLibraryChanged: @escaping () -> Void = {}
    ) {
        self.libraryImportService = libraryImportService
        self.libraryBackupService = libraryBackupService
        self.modelContext = modelContext
        self.onLibraryChanged = onLibraryChanged
    }

    func presentSheet() {
        isSheetPresented = true
    }

    func presentFolderImporter() {
        isFolderImporterPresented = true
    }

    func presentManifestImporter() {
        isManifestImporterPresented = true
    }

    func importFolder(_ url: URL) async {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        isImporting = true
        defer { isImporting = false }

        let result = await libraryImportService.importFolder(at: url, in: modelContext)
        lastResult = result
        onLibraryChanged()

        if result.totalProcessed > 0 {
            isSummaryPresented = true
        }
    }

    func applyManifest(_ url: URL) async {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        isImporting = true
        defer { isImporting = false }
        errorMessage = nil

        do {
            let result = try libraryBackupService.applyManifest(at: url, in: modelContext)
            lastBackupApplyResult = result
            onLibraryChanged()
            isBackupSummaryPresented = true
        } catch let error as LibraryBackupManifestError {
            switch error {
            case .unsupportedFormatVersion(let version):
                errorMessage = "This backup uses an unsupported format (version \(version))."
            case .invalidData:
                errorMessage = "Could not read the backup file."
            }
        } catch {
            errorMessage = "Could not restore from this backup file."
        }
    }

    func exportLibraryBackup() {
        errorMessage = nil
        do {
            let url = try libraryBackupService.exportToDocuments(in: modelContext)
            lastExportedBackupURL = url
            isExportSuccessPresented = true
        } catch {
            errorMessage = "Could not export library backup."
        }
    }

    func dismissSummary() {
        isSummaryPresented = false
        lastResult = nil
    }

    func dismissBackupSummary() {
        isBackupSummaryPresented = false
        lastBackupApplyResult = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func reportError(_ message: String) {
        errorMessage = message
    }

    var summaryMessage: String {
        guard let result = lastResult else { return "" }

        var lines: [String] = []
        if result.importedCount > 0 {
            lines.append("\(result.importedCount) audiobook\(result.importedCount == 1 ? "" : "s") imported")
        }
        if result.skippedDuplicateCount > 0 {
            lines.append("\(result.skippedDuplicateCount) duplicate\(result.skippedDuplicateCount == 1 ? "" : "s") skipped")
        }
        if result.failed.count > 0 {
            lines.append("\(result.failed.count) failed")
        }
        if lines.isEmpty {
            return "No audiobooks were imported."
        }
        return lines.joined(separator: "\n")
    }

    var backupSummaryMessage: String {
        guard let result = lastBackupApplyResult else { return "" }

        var lines: [String] = []
        if result.restoredBooks > 0 {
            lines.append("\(result.restoredBooks) book\(result.restoredBooks == 1 ? "" : "s") restored")
        }
        if result.foldersApplied > 0 {
            lines.append("\(result.foldersApplied) folder\(result.foldersApplied == 1 ? "" : "s") applied")
        }
        if result.unmatchedEntries > 0 {
            lines.append("\(result.unmatchedEntries) backup entr\(result.unmatchedEntries == 1 ? "y" : "ies") did not match your library")
        }
        if lines.isEmpty {
            return "No matching audiobooks were found in your library."
        }
        return lines.joined(separator: "\n")
    }

    var exportSuccessMessage: String {
        "Library backup saved to Files → On My iPhone → Audiopig → \(LibraryBackupService.folderName)."
    }
}
