//
//  MainTabView.swift
//  Audiopig
//
//  Root navigation shell: TabView + persistent MiniPlayer overlay.
//
//  Layout design:
//  - A ZStack contains the TabView (which fills the entire stack) and the MiniPlayer
//    overlay. The MiniPlayer is anchored to .bottom of the ZStack with .padding(.bottom,
//    tabBarHeight) so its bottom edge sits at the top of the system tab bar. The system
//    tab bar height is a well-known iOS constant (49 pt) and does NOT vary by device;
//    only the home-indicator inset below it varies, and that is already handled by the
//    ZStack respecting its parent's safe area.
//  - Each tab's content view receives a transparent .safeAreaInset so its scroll view
//    extends its bottom inset by exactly the MiniPlayer height (62 pt). Without this,
//    the last list row would scroll under the MiniPlayer and be unreachable.
//  - The full PlayerView sheet is owned here so it persists across tab switches.
//

import SwiftUI

struct MainTabView: View {

    @State private var viewModel: LibraryViewModel
    @State private var isPlayerPresented: Bool = false

    /// Standard iOS tab-bar height (does not vary by device type or screen size).
    private static let tabBarHeight: CGFloat = 49

    /// Intrinsic height of MiniPlayerView (vertical padding 11 × 2 + 40 pt art row = 62 pt).
    private static let miniPlayerHeight: CGFloat = 62

    init(libraryViewModel: LibraryViewModel) {
        _viewModel = State(initialValue: libraryViewModel)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                LibraryView(viewModel: viewModel)
                    .safeAreaInset(edge: .bottom, spacing: 0) { miniPlayerSpacer }
                    .tabItem { Label("Library", systemImage: "books.vertical") }

                SettingsView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { miniPlayerSpacer }
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }

            // MiniPlayer sits between tab-bar items and scroll content.
            // .padding(.bottom, tabBarHeight) lifts it above the 49 pt tab bar.
            if viewModel.playerViewModel.isActive {
                MiniPlayerView(
                    viewModel: viewModel.playerViewModel,
                    onTap: { isPlayerPresented = true }
                )
                .padding(.bottom, Self.tabBarHeight)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(
            .spring(response: 0.38, dampingFraction: 0.80),
            value: viewModel.playerViewModel.isActive
        )
        .sheet(isPresented: $isPlayerPresented) {
            PlayerView(viewModel: viewModel.playerViewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    /// A transparent placeholder whose height equals the MiniPlayer. Injected as a
    /// .safeAreaInset on each tab's content so scroll views extend their inset by exactly
    /// this amount, keeping the last row reachable above the MiniPlayer.
    @ViewBuilder
    private var miniPlayerSpacer: some View {
        if viewModel.playerViewModel.isActive {
            Color.clear.frame(height: Self.miniPlayerHeight)
        }
    }
}
