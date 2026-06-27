# Subtitles architecture

Canonical reference for on-device subtitle transcription. Read this before changing the pipeline.

## Glossary

| Term | Meaning |
|------|---------|
| **Cue** | One line of text with start/end times — what the user reads |
| **Segment** | Record that ASR ran on a time range — planning only |
| **Window** | Fixed 10-minute slice transcribed in one job |
| **Playhead lead-in** | 2 minutes — near-playhead window starts here before the playhead |
| **Window duration** | 10 minutes — `SubtitleWindowPlanner.defaultWindowDuration` |

## Two layers (never merge)

| Layer | Question | API | Used for |
|-------|----------|-----|----------|
| **Display** | Is there a subtitle line *right now*? | `SubtitleCueResolver.hasActiveCue` | Overlay text, `.ready` / `.needsGeneration` |
| **Planning** | Did we already run ASR on this audio? | `SubtitleSegmentPlanner` + `SubtitleTranscriptionSegment` | Queue windows, whole-book fill, coverage % |

**Cue** answers “what to show.” **Segment** answers “what to transcribe next.”

## File map

| File | Responsibility |
|------|----------------|
| `AudiopigShared/SubtitleCueResolver.swift` | Active cue lookup, visible window for display |
| `AudiopigShared/SubtitleSegmentPlanner.swift` | Segment merge, uncovered windows, near-playhead queue |
| `AudiopigShared/SubtitleWindowPlanner.swift` | Window geometry constants only |
| `AudiopigShared/SubtitleCoverageCalculator.swift` | Coverage metrics from segments |
| `Services/SubtitleGenerationOrchestrator.swift` | ASR job queue (one window near playhead; all gaps whole-book) |
| `Services/SubtitleStore.swift` | SwiftData cues + segments |
| `ViewModels/PlayerViewModel.swift` | Orchestration, paywall, epoch guards |
| `Views/Components/SubtitlesPanel.swift` | Presentation only |

## User scenarios

**Forward listening with transcribe-as-you-go:** While playing, subtitles visible, no active cue at playhead, and playhead nears the forward segment edge → near-playhead job queues the next uncovered window.

**Seek into a gap:** Overlay shows `.needsGeneration` (no lines). If Plus and subtitles visible, near-playhead generation starts for the playhead window.

**Patchy file + whole book:** Whole-book queues every window not fully covered by segments (≥99% of window duration). Re-transcribes the full 10-minute window; cue dedupe prevents duplicates.

**Silent ASR (no cues):** Segment still recorded so the window is not retried forever.

**Delete transcription:** Clears cues and segments for the book.

## Cascade guards

- `subtitleGenerationEpoch` — stale async callbacks no-op after cancel/seek
- Seek while generating — cancel + restart via `handleSubtitlesPlayheadJump`
- Empty ASR — still persist segment; do not throw `transcriptionFailed`
- Whole-book with nothing to do — success when `uncoveredWindows` is empty
- Background — near-playhead generation suspended on resign active

## Legacy backfill

On load, when segments are empty but cues exist: infer segments for windows where cue union covers ≥50% of window duration. Sparse windows stay fillable.

## Premium

Subtitles require AudioPig Plus (`PremiumFeature.subtitles`). Gated at toggle, generation, and transcribe-as-you-go.

## Changing this system

1. Update pure logic in `AudiopigShared` with tests in `AudiopigTests/Subtitle*Tests.swift`
2. Update this doc if behavior changes
3. Do not add a third “coverage” concept — keep display (cues) and planning (segments) separate
