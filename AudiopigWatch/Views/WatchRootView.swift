//
//  WatchRootView.swift
//  AudiopigWatch
//

import SwiftUI

private enum WatchScreen: Equatable {
    case sourcePicker
    case phoneRecentBooks
    case watchLocalLibrary
    case player
}

struct WatchRootView: View {
    @ObservedObject var playerViewModel: WatchPlayerViewModel
    @ObservedObject var libraryViewModel: WatchLibraryViewModel
    @ObservedObject var localLibraryViewModel: WatchLocalLibraryViewModel

    @State private var screen: WatchScreen
    @State private var selectedPage = 1

    init(
        playerViewModel: WatchPlayerViewModel,
        libraryViewModel: WatchLibraryViewModel,
        localLibraryViewModel: WatchLocalLibraryViewModel
    ) {
        _playerViewModel = ObservedObject(wrappedValue: playerViewModel)
        _libraryViewModel = ObservedObject(wrappedValue: libraryViewModel)
        _localLibraryViewModel = ObservedObject(wrappedValue: localLibraryViewModel)
        let initial: WatchScreen = playerViewModel.shouldLaunchToPlayer ? .player : .sourcePicker
        _screen = State(initialValue: initial)
    }

    var body: some View {
        Group {
            switch screen {
            case .sourcePicker:
                PlaybackSourcePickerView(
                    onSelectPhone: { screen = .phoneRecentBooks },
                    onSelectWatch: { screen = .watchLocalLibrary }
                )
            case .phoneRecentBooks:
                RecentBooksView(
                    libraryViewModel: libraryViewModel,
                    playerViewModel: playerViewModel,
                    onBookSelected: {
                        screen = .player
                        selectedPage = 1
                    },
                    onBack: { screen = .sourcePicker }
                )
            case .watchLocalLibrary:
                WatchLocalLibraryView(
                    libraryViewModel: localLibraryViewModel,
                    playerViewModel: playerViewModel,
                    onBookSelected: {
                        screen = .player
                        selectedPage = 1
                    },
                    onBack: { screen = .sourcePicker }
                )
            case .player:
                WatchPlayerPagerView(viewModel: playerViewModel, selectedPage: $selectedPage)
                    .overlay(alignment: .topLeading) {
                        backButton
                    }
            }
        }
        .toolbar(screen == .sourcePicker || screen == .player ? .hidden : .visible, for: .navigationBar)
        .onChange(of: playerViewModel.snapshot.bookID) { _, bookID in
            if bookID == nil, screen == .player {
                screen = .sourcePicker
            } else if playerViewModel.shouldLaunchToPlayer {
                screen = .player
                selectedPage = 1
            }
        }
        .onChange(of: playerViewModel.snapshot.playbackState) { _, _ in
            if playerViewModel.shouldLaunchToPlayer {
                screen = .player
                selectedPage = 1
            }
        }
    }

    private var backButton: some View {
        Button {
            screen = .sourcePicker
        } label: {
            Image(systemName: "chevron.left")
                .font(.caption.weight(.semibold))
                .padding(8)
        }
        .buttonStyle(.plain)
        .padding(.leading, 2)
        .padding(.top, 2)
    }
}
