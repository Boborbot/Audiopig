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
//  - Tab content reads `\.miniPlayerClearance` from the environment and applies
//    `.miniPlayerScrollClearance()` on its scroll views so the last row rests above
//    the mini player instead of scrolling underneath it.
//  - The full PlayerView sheet is owned here so it persists across tab switches.
//

import SwiftUI

struct MainTabView: View {

    @State private var viewModel: LibraryViewModel
    @State private var isPlayerPresented: Bool = false
    @Bindable var appSettings: AppSettings
    private let statsViewModel: StatsViewModel
    private let appIconManager: AppIconManager
    @Bindable private var settingsMonetizationViewModel: SettingsMonetizationViewModel

    /// Standard iOS tab-bar height (does not vary by device type or screen size).
    private static let tabBarHeight: CGFloat = 49

    init(
        libraryViewModel: LibraryViewModel,
        appSettings: AppSettings,
        statsViewModel: StatsViewModel,
        appIconManager: AppIconManager,
        settingsMonetizationViewModel: SettingsMonetizationViewModel
    ) {
        _viewModel = State(initialValue: libraryViewModel)
        _appSettings = Bindable(wrappedValue: appSettings)
        self.statsViewModel = statsViewModel
        self.appIconManager = appIconManager
        _settingsMonetizationViewModel = Bindable(wrappedValue: settingsMonetizationViewModel)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                LibraryView(viewModel: viewModel)
                    .tabItem { Label("Library", systemImage: "books.vertical") }

                StatsView(viewModel: statsViewModel, appIconManager: appIconManager)
                    .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

                SettingsView(
                    settings: appSettings,
                    statsViewModel: statsViewModel,
                    monetizationViewModel: settingsMonetizationViewModel,
                    libraryViewModel: viewModel
                ) {
                    viewModel.syncWatchSettings()
                }
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .environment(
                \.miniPlayerClearance,
                viewModel.playerViewModel.isActive ? DS.Layout.miniPlayerClearance : 0
            )

            // MiniPlayer sits between tab-bar items and scroll content.
            // Horizontal padding floats the pill away from screen edges;
            // the extra 6 pt bottom gap gives the shadow room to breathe
            // above the tab bar.
            if viewModel.playerViewModel.isActive {
                MiniPlayerView(
                    viewModel: viewModel.playerViewModel,
                    onTap: { isPlayerPresented = true }
                )
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.bottom, Self.tabBarHeight + 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .finishCelebrationOverlay(viewModel: viewModel)
        .animation(
            .spring(response: 0.38, dampingFraction: 0.80),
            value: viewModel.playerViewModel.isActive
        )
        .sheet(isPresented: $isPlayerPresented) {
            PlayerView(viewModel: viewModel.playerViewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: appSettings.orientationLock) { _, locked in
            OrientationLockController.shared.setLocked(locked)
        }
        .onAppear {
            syncWidgetSnapshots()
        }
        .onOpenURL { url in
            handleWidgetURL(url)
        }
    }

    private func syncWidgetSnapshots() {
        viewModel.syncWidgetRecentBooks()
    }

    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "audiopig", url.host() == "play" else { return }
        let pathComponent = url.pathComponents.filter { $0 != "/" }.last
        guard let pathComponent, let bookID = UUID(uuidString: pathComponent) else { return }
        guard viewModel.playAudiobook(id: bookID) else { return }
        isPlayerPresented = true
    }
}
