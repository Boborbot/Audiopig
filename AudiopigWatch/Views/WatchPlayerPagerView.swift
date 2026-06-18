//
//  WatchPlayerPagerView.swift
//  AudiopigWatch
//

import SwiftUI

struct WatchPlayerPagerView: View {
    @ObservedObject var viewModel: WatchPlayerViewModel
    @Binding var selectedPage: Int

    init(viewModel: WatchPlayerViewModel, selectedPage: Binding<Int>) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _selectedPage = selectedPage
    }

    var body: some View {
        TabView(selection: $selectedPage) {
            SpeedControlsView(viewModel: viewModel, isActive: selectedPage == 0)
                .tag(0)

            if viewModel.effectiveArtworkViewMode == .add {
                ArtworkControlsView(viewModel: viewModel, isActive: selectedPage == 1)
                    .tag(1)
            }

            if viewModel.effectiveArtworkViewMode == .replaceStandardControls {
                ArtworkControlsView(viewModel: viewModel, isActive: selectedPage == 1)
                    .tag(1)
            } else if viewModel.effectiveArtworkViewMode != .replaceStandardControls {
                MediaControlsView(
                    viewModel: viewModel,
                    isActive: selectedPage == mediaControlsPageIndex
                )
                .tag(mediaControlsPageIndex)
            }

            ChapterListView(
                viewModel: viewModel,
                isActive: selectedPage == viewModel.chaptersPageIndex,
                onChapterSelected: { selectedPage = viewModel.mainControlsPageIndex }
            )
            .tag(viewModel.chaptersPageIndex)
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: viewModel.effectiveArtworkViewMode) { _, _ in
            selectedPage = viewModel.mainControlsPageIndex
        }
    }

    private var mediaControlsPageIndex: Int {
        viewModel.effectiveArtworkViewMode == .add ? 2 : 1
    }
}
