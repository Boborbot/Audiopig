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

            MediaControlsView(viewModel: viewModel, isActive: selectedPage == 1)
                .tag(1)

            ChapterListView(
                viewModel: viewModel,
                isActive: selectedPage == 2,
                onChapterSelected: { selectedPage = 1 }
            )
            .tag(2)
        }
        .tabViewStyle(.verticalPage)
    }
}
