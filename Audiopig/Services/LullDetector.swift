//
//  LullDetector.swift
//  Audiopig
//
//  Finds the longest speech lulls in a time window of an audiobook.
//
//  Strategy (two complementary sources):
//  1. Chapter metadata boundaries — exact, from ResolvedChapter.startTime.
//     Always reliable for chapter-level navigation.
//  2. Audio-based silence detection — AVAssetReader at 8 kHz mono, RMS in
//     50 ms windows, dynamic threshold + gap-merging hysteresis.
//     Reliable for paragraph-level breaks (≥ 1 s pauses) in clean recordings.
//
//  Results are ranked by duration (longest = most structurally significant),
//  top 3 returned, then sorted chronologically for display (left = furthest
//  back, right = most recent).
//

import AVFoundation
import Accelerate
import Foundation

// MARK: - LullResult

struct LullResult: Sendable, Identifiable {
    /// Stable identity for use in ForEach.
    let id: UUID
    /// Absolute position on the global book timeline where speech resumes.
    /// The seek target is `endTime - 0.5` to land just before the narrator starts.
    let endTime: TimeInterval
    /// Duration of the silence span. Chapter boundaries carry a sentinel of 10.0
    /// so they always rank above typical paragraph pauses (1–3 s).
    let duration: TimeInterval
}

// MARK: - LullAnalysisState

enum LullAnalysisState {
    case idle
    case analyzing
    case results([LullResult])
}

// MARK: - LullDetector

actor LullDetector {

    // MARK: - Public

    /// Returns up to 3 significant break points inside `[windowStart, windowEnd]`.
    ///
    /// Results are sorted by `endTime` ascending (chronological) so callers can
    /// display them left-to-right with the biggest jump on the left.
    func findLulls(
        in allChapters: [ResolvedChapter],
        from windowStart: TimeInterval,
        to windowEnd: TimeInterval
    ) async throws -> [LullResult] {
        guard windowEnd > windowStart + 1 else { return [] }

        let chapterLulls = chapterBoundaryLulls(
            from: allChapters,
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        let vadLulls = try await audioSilenceLulls(
            from: allChapters,
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        let combined = merge(chapterLulls: chapterLulls, vadLulls: vadLulls)

        // Rank by duration descending → chapter boundaries (10.0) float above
        // typical paragraph breaks (1–3 s). Return top 3 sorted by time.
        return Array(combined.sorted { $0.duration > $1.duration }.prefix(3))
            .sorted { $0.endTime < $1.endTime }
    }

    // MARK: - Source 1: chapter metadata

    private func chapterBoundaryLulls(
        from chapters: [ResolvedChapter],
        windowStart: TimeInterval,
        windowEnd: TimeInterval
    ) -> [LullResult] {
        // Only include chapter starts that are meaningfully inside the window
        // (at least 2 s from the start so we don't pick up the opening of the window).
        chapters
            .filter { $0.startTime > windowStart + 2.0 && $0.startTime < windowEnd }
            .map { LullResult(id: UUID(), endTime: $0.startTime, duration: 10.0) }
    }

    // MARK: - Source 2: audio-based silence detection

    private func audioSilenceLulls(
        from allChapters: [ResolvedChapter],
        windowStart: TimeInterval,
        windowEnd: TimeInterval
    ) async throws -> [LullResult] {
        // Build a map from file URL → minimum chapter startTime (file global offset).
        // This mirrors AudioEngine.fileGlobalOffsets so we correctly convert between
        // file-local timestamps and the global book timeline.
        var fileGlobalOffsets: [URL: TimeInterval] = [:]
        for chapter in allChapters {
            let current = fileGlobalOffsets[chapter.fileURL]
            if current == nil || chapter.startTime < current! {
                fileGlobalOffsets[chapter.fileURL] = chapter.startTime
            }
        }

        // Collect the unique file URLs whose chapters overlap the analysis window.
        let overlapping = allChapters.filter {
            $0.startTime < windowEnd && $0.startTime + $0.duration > windowStart
        }
        let uniqueURLs = Set(overlapping.map { $0.fileURL })

        var allLulls: [LullResult] = []

        for fileURL in uniqueURLs {
            let fileGlobalOffset = fileGlobalOffsets[fileURL] ?? 0
            let fileLocalStart = max(0, windowStart - fileGlobalOffset)
            let fileLocalEnd = windowEnd - fileGlobalOffset
            guard fileLocalEnd > fileLocalStart else { continue }

            let samples = try await readMonoPCM(
                from: fileURL,
                start: fileLocalStart,
                end: fileLocalEnd
            )
            guard !samples.isEmpty else { continue }

            let sampleRate = 8000
            let frameDuration = 0.05           // 50 ms per frame
            let frameSize = Int(Double(sampleRate) * frameDuration)  // 400 samples
            let minSilenceFrames = Int(1.0 / frameDuration)          // 20 → 1.0 s minimum

            let silences = detectSilences(
                in: samples,
                frameSize: frameSize,
                minSilenceFrames: minSilenceFrames,
                frameDuration: frameDuration
            )

            let readOffset = fileLocalStart  // where in the file we started reading
            for silence in silences {
                let globalEnd = fileGlobalOffset + readOffset + silence.end
                // Clamp to window and skip anything that overshoots
                guard globalEnd > windowStart + 1, globalEnd < windowEnd else { continue }
                allLulls.append(LullResult(
                    id: UUID(),
                    endTime: globalEnd,
                    duration: silence.end - silence.start
                ))
            }
        }

        return allLulls
    }

    // MARK: - Merge & deduplicate

    private func merge(
        chapterLulls: [LullResult],
        vadLulls: [LullResult]
    ) -> [LullResult] {
        var result = chapterLulls
        for vadLull in vadLulls {
            // Drop a VAD lull if it falls within 2 s of an existing chapter boundary
            // (the metadata entry is more accurate for chapter starts).
            let nearChapter = result.contains { abs($0.endTime - vadLull.endTime) < 2.0 }
            if !nearChapter {
                result.append(vadLull)
            }
        }
        return result
    }

    // MARK: - AVAssetReader (8 kHz mono PCM)

    private func readMonoPCM(
        from url: URL,
        start: TimeInterval,
        end: TimeInterval
    ) async throws -> [Float] {
        let asset = AVURLAsset(
            url: url,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        )

        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else { return [] }

        let cmStart    = CMTime(seconds: start, preferredTimescale: 44100)
        let cmDuration = CMTime(seconds: max(0, end - start), preferredTimescale: 44100)
        let timeRange  = CMTimeRange(start: cmStart, duration: cmDuration)

        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = timeRange

        let outputSettings: [String: Any] = [
            AVFormatIDKey:                    Int(kAudioFormatLinearPCM),
            AVSampleRateKey:                  8000.0,
            AVNumberOfChannelsKey:            1,
            AVLinearPCMBitDepthKey:           32,
            AVLinearPCMIsFloatKey:            true,
            AVLinearPCMIsNonInterleaved:      false,
            AVLinearPCMIsBigEndianKey:        false,
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        reader.add(output)

        guard reader.startReading() else { return [] }
        defer { reader.cancelReading() }

        var samples: [Float] = []
        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
            let length = CMBlockBufferGetDataLength(blockBuffer)
            let count = length / MemoryLayout<Float>.size
            var chunk = [Float](repeating: 0, count: count)
            _ = chunk.withUnsafeMutableBytes { rawPtr in
                CMBlockBufferCopyDataBytes(
                    blockBuffer, atOffset: 0, dataLength: length,
                    destination: rawPtr.baseAddress!
                )
            }
            samples.append(contentsOf: chunk)
        }

        return samples
    }

    // MARK: - RMS silence detection

    private struct SilenceSpan {
        let start: TimeInterval  // relative to the start of the samples buffer
        let end: TimeInterval
    }

    /// Finds contiguous silence spans in `samples`.
    ///
    /// - Dynamic threshold: 12 % of mean RMS, floored at 0.004 (≈ −48 dBFS).
    ///   Self-calibrates to the narrator's typical volume.
    /// - Runs separated by fewer than 3 frames (150 ms) are merged to handle
    ///   brief consonant stops or page turns mid-silence.
    /// - Only spans of at least `minSilenceFrames` are returned (≥ 1.0 s by default).
    private func detectSilences(
        in samples: [Float],
        frameSize: Int,
        minSilenceFrames: Int,
        frameDuration: Double
    ) -> [SilenceSpan] {
        guard samples.count >= frameSize else { return [] }

        let frameCount = samples.count / frameSize

        // Compute RMS for every frame using vDSP for speed.
        var rmsValues = [Float](repeating: 0, count: frameCount)
        samples.withUnsafeBufferPointer { ptr in
            for i in 0..<frameCount {
                var rms: Float = 0
                vDSP_rmsqv(ptr.baseAddress! + i * frameSize, 1, &rms, vDSP_Length(frameSize))
                rmsValues[i] = rms
            }
        }

        // Dynamic threshold.
        var meanRMS: Float = 0
        vDSP_meanv(rmsValues, 1, &meanRMS, vDSP_Length(frameCount))
        let threshold = max(meanRMS * 0.12, 0.004)

        // Collect contiguous silent runs.
        var silentRuns: [(start: Int, end: Int)] = []
        var runStart: Int? = nil
        for i in 0...frameCount {
            let isSilent = i < frameCount && rmsValues[i] < threshold
            if isSilent, runStart == nil {
                runStart = i
            } else if !isSilent, let s = runStart {
                silentRuns.append((start: s, end: i))
                runStart = nil
            }
        }

        // Merge runs whose gap is smaller than the hysteresis window (3 frames = 150 ms).
        let hysteresisGap = 3
        var merged: [(start: Int, end: Int)] = []
        for run in silentRuns {
            if let last = merged.last, run.start - last.end < hysteresisGap {
                merged[merged.count - 1] = (start: last.start, end: run.end)
            } else {
                merged.append(run)
            }
        }

        // Filter short spans and convert frame indices to TimeInterval.
        return merged
            .filter { $0.end - $0.start >= minSilenceFrames }
            .map { SilenceSpan(
                start: Double($0.start) * frameDuration,
                end:   Double($0.end)   * frameDuration
            )}
    }
}
