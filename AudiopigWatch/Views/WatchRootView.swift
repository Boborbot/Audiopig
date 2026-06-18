//
//  WatchRootView.swift
//  AudiopigWatch
//

import SwiftUI

private enum WatchScreen: Equatable {
    case sourcePicker
    case phoneRecentBooks
    case player
}

struct WatchRootView: View {
    @ObservedObject var playerViewModel: WatchPlayerViewModel
    @ObservedObject var libraryViewModel: WatchLibraryViewModel

    @State private var screen: WatchScreen
    @State private var selectedPage: Int
    @State private var userDismissedPlayer = false

    init(
        playerViewModel: WatchPlayerViewModel,
        libraryViewModel: WatchLibraryViewModel
    ) {
        _playerViewModel = ObservedObject(wrappedValue: playerViewModel)
        _libraryViewModel = ObservedObject(wrappedValue: libraryViewModel)
        let initial: WatchScreen = playerViewModel.shouldLaunchToPlayer ? .player : .sourcePicker
        _screen = State(initialValue: initial)
        _selectedPage = State(initialValue: playerViewModel.mainControlsPageIndex)
    }

    var body: some View {
        Group {
            switch screen {
            case .sourcePicker:
                PlaybackSourcePickerView(
                    onSelectPhone: {
                        playerViewModel.preferLocalPlayback(false)
                        screen = .phoneRecentBooks
                    },
                    onSelectWatch: {}
                )
            case .phoneRecentBooks:
                RecentBooksView(
                    libraryViewModel: libraryViewModel,
                    playerViewModel: playerViewModel,
                    onBookSelected: {
                        openPlayer()
                    },
                    onBack: { screen = .sourcePicker }
                )
            case .player:
                WatchPlayerPagerView(viewModel: playerViewModel, selectedPage: $selectedPage)
                    .overlay(alignment: .topLeading) {
                        backButton
                            .zIndex(1)
                    }
            }
        }
        .toolbar(screen == .sourcePicker || screen == .player ? .hidden : .visible, for: .navigationBar)
        .onChange(of: playerViewModel.snapshot.bookID) { _, bookID in
            if bookID == nil, screen == .player {
                screen = .sourcePicker
                userDismissedPlayer = false
            } else {
                autoLaunchToPlayerIfNeeded()
            }
        }
        .onChange(of: playerViewModel.snapshot.playbackState) { oldState, newState in
            guard !userDismissedPlayer else { return }
            guard allowsRemoteAutoLaunch else { return }
            let becameActive = !oldState.isActive && newState.isActive
            if becameActive, playerViewModel.snapshot.bookID != nil {
                screen = .player
                selectedPage = playerViewModel.mainControlsPageIndex
            }
        }
    }

    private var allowsRemoteAutoLaunch: Bool {
        switch screen {
        case .sourcePicker:
            return false
        case .phoneRecentBooks, .player:
            return playerViewModel.snapshot.source != .local
        }
    }

    private var backButton: some View {
        Button {
            dismissPlayer()
        } label: {
            Image(systemName: "chevron.left")
                .font(.caption.weight(.semibold))
                .frame(minWidth: 36, minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 2)
        .padding(.top, 2)
    }

    private func openPlayer() {
        userDismissedPlayer = false
        playerViewModel.preferLocalPlayback(false)
        screen = .player
        selectedPage = playerViewModel.mainControlsPageIndex
    }

    private func dismissPlayer() {
        userDismissedPlayer = true
        screen = .phoneRecentBooks
    }

    private func autoLaunchToPlayerIfNeeded() {
        guard playerViewModel.shouldLaunchToPlayer, !userDismissedPlayer else { return }
        guard allowsRemoteAutoLaunch else { return }
        screen = .player
        selectedPage = playerViewModel.mainControlsPageIndex
    }
}
