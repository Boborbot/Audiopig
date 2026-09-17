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
    @State private var selectedPage: WatchPlayerPageKind = .media

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
        _selectedPage = State(initialValue: playerViewModel.mainControlsPage)
    }

    var body: some View {
        NavigationStack {
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
                    onBookSelected: openPlayer,
                    onBack: { screen = .sourcePicker }
                )
            case .watchLocalLibrary:
                WatchLocalLibraryView(
                    libraryViewModel: localLibraryViewModel,
                    playerViewModel: playerViewModel,
                    onBookSelected: openPlayer,
                    onBack: { screen = .sourcePicker }
                )
            case .player:
                WatchPlayerPagerView(
                    viewModel: playerViewModel,
                    selectedPage: $selectedPage,
                    onExit: showRecentBooks
                )
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .onChange(of: playerViewModel.snapshot.bookID) { _, bookID in
            if bookID == nil, screen == .player {
                screen = .sourcePicker
            }
        }
    }

    private func openPlayer() {
        selectedPage = playerViewModel.mainControlsPage
        screen = .player
    }

    private func showRecentBooks() {
        screen = .phoneRecentBooks
    }
}
