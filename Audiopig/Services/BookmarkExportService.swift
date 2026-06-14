//
//  BookmarkExportService.swift
//  Audiopig
//
//  Writes bookmark exports to Documents/Exported Bookmarks/ for browsing in the Files app.
//

import Foundation

enum BookmarkExportService {

    static let folderName = "Exported Bookmarks"

    // MARK: - Paths

    static func exportFolderURL() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ExportError.documentsUnavailable
        }
        let folder = documents.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    static func allExportedFiles() -> [URL] {
        guard let folder = try? exportFolderURL() else { return [] }
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls
            .filter { $0.pathExtension.lowercased() == "txt" }
            .sorted { lhs, rhs in
                let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lDate > rDate
            }
    }

    // MARK: - Export

    /// Writes a `.txt` export for the audiobook. Returns `nil` when the book has no bookmarks.
    @discardableResult
    static func export(_ audiobook: Audiobook) throws -> URL? {
        guard !audiobook.bookmarks.isEmpty else { return nil }

        let sorted = audiobook.bookmarks.sorted { $0.timestamp < $1.timestamp }
        let text = generateText(for: audiobook, bookmarks: sorted)
        let url = try exportFileURL(for: audiobook.title)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Text Generation

    static func generateText(for audiobook: Audiobook, bookmarks: [Bookmark]) -> String {
        let dateStr = DateFormatter.localizedString(from: .now, dateStyle: .long, timeStyle: .none)
        let rule = String(repeating: "─", count: 60)

        var lines: [String] = []
        lines.append("AUDIOBOOK BOOKMARKS")
        lines.append(rule)
        lines.append("Book:     \(audiobook.title)")
        lines.append("Author:   \(audiobook.author)")
        lines.append("Length:   \(formatTime(audiobook.duration))")
        lines.append("Exported: \(dateStr)")
        lines.append(rule)
        lines.append("")

        let tsWidth = 10
        let nameWidth = 28
        let headingTS = pad("Timestamp", tsWidth)
        let headingName = pad("Name", nameWidth)
        lines.append("\(headingTS)  \(headingName)  Note")
        lines.append("\(pad("", tsWidth, fill: "─"))  \(pad("", nameWidth, fill: "─"))  \(String(repeating: "─", count: 36))")

        for bm in bookmarks {
            let ts = pad(formatTime(bm.timestamp), tsWidth)
            let name = pad(bm.title, nameWidth)
            lines.append("\(ts)  \(name)  \(bm.note)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private enum ExportError: Error {
        case documentsUnavailable
    }

    private static func exportFileURL(for title: String) throws -> URL {
        let filename = "\(safeFilename(for: title))_bookmarks.txt"
        return try exportFolderURL().appendingPathComponent(filename)
    }

    private static func safeFilename(for title: String) -> String {
        let safe = title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return safe.isEmpty ? "bookmarks" : safe
    }

    private static func formatTime(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private static func pad(_ s: String, _ width: Int, fill: Character = " ") -> String {
        if fill == " " {
            return s.count >= width ? s : s + String(repeating: fill, count: width - s.count)
        }
        return String(repeating: fill, count: width)
    }
}
