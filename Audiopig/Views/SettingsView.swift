//
//  SettingsView.swift
//  Audiopig
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    var statsViewModel: StatsViewModel
    @Bindable var monetizationViewModel: SettingsMonetizationViewModel
    var libraryViewModel: LibraryViewModel?
    var onWatchSettingsChanged: (() -> Void)?

    @State private var isDeleteStatsConfirmationPresented = false
    @State private var isShareAllExportedPresented = false
    @State private var shareAllExportedItems: [Any] = []
    @State private var exportedNoteCount = 0

    private static let skipIntervalOptions: [TimeInterval] = [5, 10, 15, 30, 45, 60]
    private static let lullLookbackOptions: [TimeInterval] = stride(from: 1, through: 15, by: 1).map { TimeInterval($0 * 60) }
    private static let lullSkipRecentOptions: [TimeInterval] = [0, 10, 20, 30, 45, 60, 90, 120]

    init(
        settings: AppSettings,
        statsViewModel: StatsViewModel,
        monetizationViewModel: SettingsMonetizationViewModel,
        libraryViewModel: LibraryViewModel? = nil,
        onWatchSettingsChanged: (() -> Void)? = nil
    ) {
        _settings = Bindable(wrappedValue: settings)
        self.statsViewModel = statsViewModel
        _monetizationViewModel = Bindable(wrappedValue: monetizationViewModel)
        self.libraryViewModel = libraryViewModel
        self.onWatchSettingsChanged = onWatchSettingsChanged
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(isOn: $settings.orientationLock) {
                        Label("Lock orientation", systemImage: "lock.rotation")
                    }
                    .tint(DS.Color.coral)
                } header: {
                    Text("Appearance")
                        .sectionTitle()
                } footer: {
                    Text("When enabled, the app stays in portrait orientation.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.tertiary)
                }

                Section {
                    Picker("Default Speed", selection: $settings.defaultSpeed) {
                        ForEach(PlayerViewModel.availableSpeeds, id: \.self) { speed in
                            Text(speedLabel(speed)).tag(speed)
                        }
                    }
                    .tint(DS.Color.coral)

                    Picker("Speed Button 1", selection: $settings.speedPreset1) {
                        ForEach(PlayerViewModel.availableSpeeds, id: \.self) { speed in
                            Text(speedLabel(speed)).tag(speed)
                        }
                    }
                    .tint(DS.Color.coral)
                    .onChange(of: settings.speedPreset1) { _, _ in onWatchSettingsChanged?() }

                    Picker("Speed Button 2", selection: $settings.speedPreset2) {
                        ForEach(PlayerViewModel.availableSpeeds, id: \.self) { speed in
                            Text(speedLabel(speed)).tag(speed)
                        }
                    }
                    .tint(DS.Color.coral)
                    .onChange(of: settings.speedPreset2) { _, _ in onWatchSettingsChanged?() }

                    Picker("Speed Button 3", selection: $settings.speedPreset3) {
                        ForEach(PlayerViewModel.availableSpeeds, id: \.self) { speed in
                            Text(speedLabel(speed)).tag(speed)
                        }
                    }
                    .tint(DS.Color.coral)
                    .onChange(of: settings.speedPreset3) { _, _ in onWatchSettingsChanged?() }

                    Picker("Skip Forward", selection: $settings.skipForwardInterval) {
                        ForEach(Self.skipIntervalOptions, id: \.self) { seconds in
                            Text("\(Int(seconds))s").tag(seconds)
                        }
                    }
                    .tint(DS.Color.coral)
                    .onChange(of: settings.skipForwardInterval) { _, _ in onWatchSettingsChanged?() }

                    Picker("Skip Backward", selection: $settings.skipBackwardInterval) {
                        ForEach(Self.skipIntervalOptions, id: \.self) { seconds in
                            Text("\(Int(seconds))s").tag(seconds)
                        }
                    }
                    .tint(DS.Color.coral)
                    .onChange(of: settings.skipBackwardInterval) { _, _ in onWatchSettingsChanged?() }
                } header: {
                    Text("Playback")
                        .sectionTitle()
                }

                Section {
                    Picker("Look back", selection: $settings.lullLookbackWindow) {
                        ForEach(Self.lullLookbackOptions, id: \.self) { seconds in
                            Text("\(Int(seconds / 60)) min").tag(seconds)
                        }
                    }
                    .tint(DS.Color.coral)

                    Picker("Skip recent", selection: $settings.lullSkipRecentWindow) {
                        ForEach(Self.lullSkipRecentOptions, id: \.self) { seconds in
                            if seconds == 0 {
                                Text("Off").tag(seconds)
                            } else {
                                Text("\(Int(seconds))s").tag(seconds)
                            }
                        }
                    }
                    .tint(DS.Color.coral)
                } header: {
                    Text("Paragraph Breaks")
                        .sectionTitle()
                } footer: {
                    Text("Controls how far back Find Paragraph Breaks analyzes, and how much recent audio is ignored.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.tertiary)
                }

                Section {
                    Toggle(isOn: $settings.autoDeleteOnFinish) {
                        Label("Delete book when finished", systemImage: "checkmark.circle")
                    }
                    .tint(DS.Color.coral)

                    Toggle(isOn: $settings.trackReadingStats) {
                        Label("Track reading stats", systemImage: "chart.bar")
                    }
                    .tint(DS.Color.coral)

                    if settings.trackReadingStats {
                        Button(role: .destructive) {
                            isDeleteStatsConfirmationPresented = true
                        } label: {
                            Label("Delete all reading data", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Library")
                        .sectionTitle()
                } footer: {
                    Text("Reading data is stored only on this device and is never shared.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.tertiary)
                }

                Section {
                    Toggle(isOn: $settings.autoExportOnFinish) {
                        Label("Auto-export on book completion", systemImage: "bookmark")
                    }
                    .tint(DS.Color.coral)

                    Toggle(isOn: $settings.autoExportOnDelete) {
                        Label("Auto-export on book removal", systemImage: "bookmark")
                    }
                    .tint(DS.Color.coral)

                    Button {
                        shareAllExportedNotes()
                    } label: {
                        Label("Share All Exported Notes", systemImage: "square.and.arrow.up")
                    }
                    .disabled(exportedNoteCount == 0)
                } header: {
                    Text("Bookmark Export")
                        .sectionTitle()
                } footer: {
                    Text("Notes are saved to On My iPhone › Audiopig › Exported Bookmarks and are visible in the Files app.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.tertiary)
                }

                Section {
                    if let libraryViewModel {
                        NavigationLink {
                            WatchLibraryManagementView(libraryViewModel: libraryViewModel)
                        } label: {
                            Label("Watch Library", systemImage: "applewatch.and.arrow.down")
                        }
                    }

                    Toggle(isOn: $settings.watchArtworkSkipGesturesEnabled) {
                        Label("Artwork skip gestures", systemImage: "applewatch")
                    }
                    .tint(DS.Color.coral)
                    .onChange(of: settings.watchArtworkSkipGesturesEnabled) { _, _ in
                        onWatchSettingsChanged?()
                    }
                } header: {
                    Text("Apple Watch")
                        .sectionTitle()
                } footer: {
                    Text("When enabled, double-tap on the Watch player artwork zone skips forward; triple-tap skips back.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.tertiary)
                }

                plusSection
                TipJarSection(viewModel: monetizationViewModel)

                Section {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                    Label("Version \(version) (\(build))", systemImage: "info.circle")
                        .foregroundStyle(DS.Color.secondary)
                } header: {
                    Text("About")
                        .sectionTitle()
                } footer: {
                    Link(destination: AppSupport.privacyPolicyURL) {
                        Text("Privacy Policy")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.tertiary)
                    }
                    .tint(DS.Color.tertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.Color.canvas.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .coralNavigationBanner()
            .alert("Delete all reading data?", isPresented: $isDeleteStatsConfirmationPresented) {
                Button("Delete", role: .destructive) { statsViewModel.deleteAllStats() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your entire reading history will be permanently removed. This cannot be undone.")
            }
            .sheet(isPresented: $isShareAllExportedPresented) {
                ShareActivityView(activityItems: shareAllExportedItems)
            }
            .onAppear { refreshExportedNoteCount() }
            .task { await monetizationViewModel.onAppear() }
        }
    }

    // MARK: - Audiopig Plus

    private var plusSection: some View {
        Section {
            Label(monetizationViewModel.plusStatusLine, systemImage: "sparkles")
                .foregroundStyle(DS.Color.secondary)

            if monetizationViewModel.showsSubscribeAction {
                Button {
                    Task { await monetizationViewModel.subscribeToPlus() }
                } label: {
                    if monetizationViewModel.isProcessing {
                        HStack {
                            Text("Subscribe to Audiopig Plus")
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.85)
                        }
                    } else if let price = monetizationViewModel.plusDisplayPrice {
                        Text("Subscribe to Audiopig Plus — \(price)/mo")
                    } else {
                        Text("Subscribe to Audiopig Plus")
                    }
                }
                .disabled(monetizationViewModel.isProcessing)
            }

            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                Label("Manage Subscription", systemImage: "creditcard")
            }

            Button {
                Task { await monetizationViewModel.restorePurchases() }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
            }
            .disabled(monetizationViewModel.isProcessing)

            if let errorMessage = monetizationViewModel.errorMessage {
                Text(errorMessage)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Audiopig Plus")
                .sectionTitle()
        } footer: {
            Text("Find Paragraph Breaks is included with Plus. Core playback stays free.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.tertiary)
        }
    }

    // MARK: - Bookmark export

    private func refreshExportedNoteCount() {
        exportedNoteCount = BookmarkExportService.allExportedFiles().count
    }

    private func shareAllExportedNotes() {
        let files = BookmarkExportService.allExportedFiles()
        guard !files.isEmpty else { return }
        shareAllExportedItems = files
        isShareAllExportedPresented = true
    }

    private func speedLabel(_ speed: Float) -> String {
        speed.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(speed))×"
            : String(format: "%.2g×", speed)
    }
}
