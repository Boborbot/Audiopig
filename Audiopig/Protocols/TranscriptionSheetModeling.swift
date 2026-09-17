//
//  TranscriptionSheetModeling.swift
//  Audiopig
//

import Foundation

/// Shared surface for the transcription options sheet (player and library).
@MainActor
protocol TranscriptionSheetModeling: AnyObject {
    var transcribeAsYouGoEnabled: Bool { get set }
    var subtitlesSupported: Bool { get }
    var hasSavedSubtitles: Bool { get }
    var subtitleCoverageTimeline: SubtitleCoverageTimeline { get }
    var subtitleCoverageSummary: SubtitleCoverageSummary { get }
    var isInWholeBookTranscriptionQueue: Bool { get }
    var wholeBookQueuePosition: Int? { get }
    var wholeBookJobState: WholeBookSubtitleJobStateKind { get }
    var hasUncoveredSubtitleWindows: Bool { get }
    var hasUncoveredSubtitleWindowsFromCurrentPosition: Bool { get }
    var onShowTranscriptionQueue: (() -> Void)? { get }

    func generateSubtitlesWholeBook()
    func generateSubtitlesFromCurrentPosition()
    func pauseWholeBookTranscription()
    func resumeWholeBookTranscription()
    func cancelWholeBookTranscription()
    func exportSubtitles(format: SubtitleExportFormat) throws -> URL?
    func deleteSavedTranscription()
}
