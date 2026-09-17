//
//  WatchPlayerPagerView.swift
//  AudiopigWatch
//

import SwiftUI

/// Vertical player: speed, transport, optional artwork, chapters.
///
/// watchOS `TabView` + Digital Crown crashes when opening the player from Recent
/// Books. This pager keeps a single page in the hierarchy (one crown handler)
/// and moves with chevrons or a vertical swipe.
struct WatchPlayerPagerView: View {
    @ObservedObject var viewModel: WatchPlayerViewModel
    @Binding var selectedPage: WatchPlayerPageKind
    let onExit: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVolumeCrownReady = false

    init(
        viewModel: WatchPlayerViewModel,
        selectedPage: Binding<WatchPlayerPageKind>,
        onExit: @escaping () -> Void
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _selectedPage = selectedPage
        self.onExit = onExit
    }

    var body: some View {
        VStack(spacing: 0) {
            playerNavigationRow

            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if hasNextPage {
                pageChevron(systemName: "chevron.compact.down", action: goToNextPage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(WatchPlayerPageSwipeModifier(
            allowsVerticalPaging: selectedPage != .chapters,
            onSwipeToPrevious: goToPreviousPage,
            onSwipeToNext: goToNextPage,
            onExit: onExit
        ))
        .watchVolumeCrown(
            viewModel: viewModel,
            isActive: isVolumePage && isVolumeCrownReady
        )
        .task(id: volumeCrownActivationID) {
            isVolumeCrownReady = false
            guard scenePhase == .active, isVolumePage else { return }

            // Avoid registering focus and Crown input in the same transition
            // that replaces the library with the player.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            isVolumeCrownReady = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.handleSceneBecameActive()
            }
        }
        .onChange(of: viewModel.effectiveArtworkViewMode) { _, _ in
            selectedPage = viewModel.resolvedPlayerPage(selectedPage)
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .speed:
            SpeedControlsView(viewModel: viewModel, isActive: true)
        case .media:
            MediaControlsView(viewModel: viewModel)
        case .artwork:
            ArtworkControlsView(viewModel: viewModel)
        case .chapters:
            ChapterListView(viewModel: viewModel) {
                selectedPage = viewModel.mainControlsPage
            }
        }
    }

    private var pages: [WatchPlayerPageKind] {
        viewModel.playerPages
    }

    private var isVolumePage: Bool {
        selectedPage == .media || selectedPage == .artwork
    }

    private var volumeCrownActivationID: String {
        "\(selectedPage.rawValue):\(scenePhase == .active)"
    }

    private var currentIndex: Int {
        pages.firstIndex(of: selectedPage) ?? 0
    }

    private var hasPreviousPage: Bool {
        currentIndex > 0
    }

    private var hasNextPage: Bool {
        currentIndex < pages.count - 1
    }

    private func goToPreviousPage() {
        guard hasPreviousPage else { return }
        selectedPage = pages[currentIndex - 1]
        WatchHaptics.directionUp()
    }

    private func goToNextPage() {
        guard hasNextPage else { return }
        selectedPage = pages[currentIndex + 1]
        WatchHaptics.directionDown()
    }

    private var playerNavigationRow: some View {
        HStack(spacing: WDS.Spacing.xs) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .frame(width: 32, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to recent books")

            if hasPreviousPage {
                pageChevron(systemName: "chevron.compact.up", action: goToPreviousPage)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 2)
    }

    private func pageChevron(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName.contains("up") ? "Previous player page" : "Next player page")
    }
}

private struct WatchPlayerPageSwipeModifier: ViewModifier {
    let allowsVerticalPaging: Bool
    let onSwipeToPrevious: () -> Void
    let onSwipeToNext: () -> Void
    let onExit: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let action = WatchPlayerSwipeResolver.action(
                        horizontal: Double(value.translation.width),
                        vertical: Double(value.translation.height),
                        allowsVerticalPaging: allowsVerticalPaging
                    )
                    switch action {
                    case .none:
                        break
                    case .previousPage:
                        onSwipeToPrevious()
                    case .nextPage:
                        onSwipeToNext()
                    case .exitPlayer:
                        onExit()
                    }
                }
        )
    }
}
