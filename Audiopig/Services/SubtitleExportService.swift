//
//  SubtitleExportService.swift
//  Audiopig
//

import Foundation

enum SubtitleExportFormat: String, CaseIterable {
    case plainText
    case srt

    var fileExtension: String {
        switch self {
        case .plainText: return "txt"
        case .srt: return "srt"
        }
    }

    var label: String {
        switch self {
        case .plainText: return "Plain Text"
        case .srt: return "SRT Subtitles"
        }
    }
}

enum SubtitleExportService {

    static let folderName = "Exported Subtitles"

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

    @discardableResult
    static func export(
        audiobook: Audiobook,
        cues: [SubtitleCueTiming],
        format: SubtitleExportFormat
    ) throws -> URL? {
        guard !cues.isEmpty else { return nil }

        let body: String
        switch format {
        case .plainText:
            body = generatePlainText(audiobook: audiobook, cues: cues)
        case .srt:
            body = generateSRT(cues: cues)
        }

        let url = try exportFileURL(for: audiobook.title, format: format)
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func generatePlainText(audiobook: Audiobook, cues: [SubtitleCueTiming]) -> String {
        let rule = String(repeating: "─", count: 60)
        var lines: [String] = [
            "AUDIOBOOK SUBTITLES",
            rule,
            "Book:   \(audiobook.title)",
            "Author: \(audiobook.author)",
            rule,
            "",
        ]

        for cue in cues {
            lines.append("[\(formatTime(cue.startTime))] \(cue.text)")
        }
        return lines.joined(separator: "\n")
    }

    static func generateSRT(cues: [SubtitleCueTiming]) -> String {
        cues.enumerated().map { index, cue in
            let start = formatSRTTime(cue.startTime)
            let end = formatSRTTime(cue.endTime)
            return "\(index + 1)\n\(start) --> \(end)\n\(cue.text)\n"
        }.joined(separator: "\n")
    }

    private enum ExportError: Error {
        case documentsUnavailable
    }

    private static func exportFileURL(for title: String, format: SubtitleExportFormat) throws -> URL {
        let filename = "\(safeFilename(for: title))_subtitles.\(format.fileExtension)"
        return try exportFolderURL().appendingPathComponent(filename)
    }

    private static func safeFilename(for title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return title
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
            .description
    }

    private static func formatTime(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func formatSRTTime(_ interval: TimeInterval) -> String {
        let totalMs = max(0, Int((interval * 1000).rounded()))
        let hours = totalMs / 3_600_000
        let minutes = (totalMs % 3_600_000) / 60_000
        let seconds = (totalMs % 60_000) / 1000
        let millis = totalMs % 1000
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, millis)
    }
}
