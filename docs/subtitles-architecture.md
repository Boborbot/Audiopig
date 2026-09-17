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
| `Services/SubtitleGenerationOrchestrator.swift` | ASR job queue (one window near playhead; all gaps whole-book; from-current skips earlier sections) |
| `Services/WholeBookTranscriptionQueueService.swift` | Global serial whole-book queue, persistence, worker |
| `Services/SubtitleStore.swift` | SwiftData cues + segments |
| `ViewModels/PlayerViewModel.swift` | Near-playhead orchestration, paywall, epoch guards |
| `ViewModels/LibraryViewModel.swift` | Library enqueue, queue sheet presentation |
| `Views/Components/SubtitlesPanel.swift` | Presentation only |

## User scenarios

**Forward listening with transcribe-as-you-go:** While playing, subtitles visible, no active cue at playhead, and playhead nears the forward segment edge → near-playhead job queues the next uncovered window.

**Seek into a gap:** Overlay shows `.needsGeneration` (no lines). If Plus and subtitles visible, near-playhead generation starts for the playhead window.

**Patchy file + whole book:** Whole-book queues every window not fully covered by segments (≥99% of window duration). Re-transcribes the full 10-minute window; cue dedupe prevents duplicates.

**From current position:** Same queue as whole-book, but only the 10-minute section containing the playhead and every later uncovered window. Earlier sections are never queued, even if they have gaps. The playhead is captured at enqueue time and persisted so seek or relaunch cannot expand the job backward.

**Multi-book queue:** User enqueues books from the subtitles sheet (player or library swipe), or queue retry. Library swipe opens the same transcription sheet without “transcribe as you go.” `WholeBookTranscriptionQueueService` processes one book at a time; order is persisted and reorderable from the library capsule queue sheet. Queue rows show the coverage timeline (which sections are saved) rather than a linear progress bar. The queue button appears in the library toolbar capsule only while work remains.

**Silent ASR (no cues):** Segment still recorded so the window is not retried forever.

**Delete transcription:** Clears cues and segments for the book.

## Cascade guards

- `subtitleGenerationEpoch` — stale async callbacks no-op after cancel/seek
- Seek while generating — cancel + restart via `handleSubtitlesPlayheadJump`
- Empty ASR — still persist segment; do not throw `transcriptionFailed`
- Whole-book with nothing to do — success when `uncoveredWindows` is empty
- From current position with nothing left ahead — enqueue returns complete for that range; does not mark the whole book complete
- Background — near-playhead generation suspended on resign active; whole-book queue continues
- App relaunch — `restoreOnLaunch` re-queues orphaned `.inProgress` whole-book and from-current-position jobs
- Near-playhead blocked while any whole-book queue job is active (ASR contention)

## Legacy backfill

On load, when segments are empty but cues exist: infer segments for windows where cue union covers ≥50% of window duration. Sparse windows stay fillable.

## Premium

Subtitles require AudioPig Plus (`PremiumFeature.subtitles`). Gated at toggle, generation, and transcribe-as-you-go.

## Changing this system

1. Update pure logic in `AudiopigShared` with tests in `AudiopigTests/Subtitle*Tests.swift`
2. Update this doc if behavior changes
3. Do not add a third “coverage” concept — keep display (cues) and planning (segments) separate
