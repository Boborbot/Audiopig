#if DEBUG
import SwiftUI

@MainActor
struct WatchPlayerSmokeTestView: View {
    @ObservedObject var viewModel: WatchPlayerViewModel
    @State private var selectedPage: WatchPlayerPageKind

    init(viewModel: WatchPlayerViewModel, page: WatchPlayerPageKind) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _selectedPage = State(initialValue: page)
    }

    var body: some View {
        WatchPlayerPagerView(
            viewModel: viewModel,
            selectedPage: $selectedPage,
            onExit: {}
        )
            .task {
                guard ProcessInfo.processInfo.arguments.contains(
                    "--watch-player-smoke-cycle"
                ) else {
                    return
                }

                for page in [
                    WatchPlayerPageKind.speed,
                    .chapters,
                    .media
                ] {
                    try? await Task.sleep(for: .milliseconds(750))
                    guard !Task.isCancelled else { return }
                    selectedPage = page
                }
            }
    }
}

@MainActor
final class WatchPlayerSmokeTestCoordinator: WatchPlaybackCoordinating {
    private let bookID = UUID()
    private var snapshotHandler: ((WatchPlaybackSnapshot) -> Void)?

    private(set) lazy var snapshot: WatchPlaybackSnapshot? = WatchPlaybackSnapshot(
        revision: 1,
        bookID: bookID,
        title: "Player Smoke Test",
        author: "AudioPig",
        chapterTitle: "Chapter 2",
        playbackState: .paused,
        playbackSpeed: 1.2,
        skipForwardSeconds: 30,
        skipBackwardSeconds: 15,
        chapterIndex: 1,
        chapterCount: 3,
        chapterElapsed: 120,
        chapterDuration: 600,
        chapterProgress: 0.2,
        globalCurrentTime: 720,
        globalDuration: 3_600,
        systemVolume: 0.5,
        source: .remote,
        artworkJPEG: nil
    )

    let isReachable = true

    func send(_ command: WatchCommand) async -> WatchCommandResult {
        switch command {
        case .requestChapters:
            return .ok(snapshot: snapshot, chapters: chaptersPayload)
        default:
            return .ok(snapshot: snapshot)
        }
    }

    func setSnapshotHandler(_ handler: @escaping (WatchPlaybackSnapshot) -> Void) {
        snapshotHandler = handler
        if let snapshot {
            handler(snapshot)
        }
    }

    private var chaptersPayload: WatchChaptersPayload {
        WatchChaptersPayload(
            bookID: bookID,
            chapters: (0..<3).map { index in
                WatchChapterSummary(
                    id: UUID(),
                    title: "Chapter \(index + 1)",
                    startTime: TimeInterval(index * 600),
                    duration: 600,
                    orderIndex: index
                )
            }
        )
    }
}
#endif
