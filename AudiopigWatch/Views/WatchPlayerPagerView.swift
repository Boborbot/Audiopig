//
//  WatchPlayerPagerView.swift
//  AudiopigWatch
//

import SwiftUI

/// Single-screen remote player. Avoids vertical `TabView` + multiple crown handlers,
/// which have been crashing on device when opening from Recent Books.
struct WatchPlayerPagerView: View {
    @ObservedObject var viewModel: WatchPlayerViewModel
    @Binding var selectedPage: Int
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: WatchPlayerViewModel, selectedPage: Binding<Int>) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _selectedPage = selectedPage
    }

    var body: some View {
        MediaControlsView(viewModel: viewModel, isActive: true)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.handleSceneBecameActive()
                }
            }
            .onAppear {
                selectedPage = viewModel.mainControlsPageIndex
            }
    }
}
