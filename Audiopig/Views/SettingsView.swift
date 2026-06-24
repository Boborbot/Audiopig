//
//  SettingsView.swift
//  Audiopig
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    var statsViewModel: StatsViewModel
    @Bindable var monetizationViewModel: SettingsMonetizationViewModel
    var onWatchSettingsChanged: (() -> Void)?

    @State private var isDeleteStatsConfirmationPresented = false
    @State private var isDeleteStatsFinalConfirmationPresented = false
    @State private var isShareAllExportedPresented = false
    @State private var shareAllExportedItems: [Any] = []
    @State private var exportedNoteCount = 0

    init(
        settings: AppSettings,
        statsViewModel: StatsViewModel,
        monetizationViewModel: SettingsMonetizationViewModel,
        onWatchSettingsChanged: (() -> Void)? = nil
    ) {
        _settings = Bindable(wrappedValue: settings)
        self.statsViewModel = statsViewModel
        _monetizationViewModel = Bindable(wrappedValue: monetizationViewModel)
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
                    NavigationLink {
                        PlaybackControlsSettingsView(
                            settings: settings,
                            onWatchSettingsChanged: onWatchSettingsChanged
                        )
                    } label: {
                        Label("Playback Controls", systemImage: "playpause")
                    }
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
                    Text("Notes are saved to On My iPhone › \(Brand.displayName) › Exported Bookmarks and are visible in the Files app.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.tertiary)
                }

                Section {
                    Picker("Artwork view", selection: $settings.watchArtworkViewMode) {
                        ForEach(WatchArtworkViewMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .disabled(!monetizationViewModel.hasAccess(to: .watchArtworkView))
                    .opacity(monetizationViewModel.hasAccess(to: .watchArtworkView) ? 1 : 0.45)
                    .onChange(of: settings.watchArtworkViewMode) { _, _ in
                        onWatchSettingsChanged?()
                    }

                    Toggle(isOn: $settings.watchArtworkSkipGesturesEnabled) {
                        Label("Artwork skip gestures", systemImage: "hand.tap")
                    }
                    .tint(DS.Color.coral)
                    .onChange(of: settings.watchArtworkSkipGesturesEnabled) { _, _ in
                        onWatchSettingsChanged?()
                    }
                } header: {
                    Text("Apple Watch")
                        .sectionTitle()
                } footer: {
                    Text("Artwork view shows cover art with play and skip controls on the Watch player. Off leaves controls unchanged. Replace swaps the main controls screen; Add inserts an extra screen between controls and speed.")
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
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        LegalDocumentLinks()
                        Link("Contact Support", destination: AppSupport.supportEmailURL)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.tertiary)
                            .tint(DS.Color.tertiary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.Color.canvas.ignoresSafeArea())
            .miniPlayerScrollClearance()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .coralNavigationBanner()
            .alert("Are you sure?", isPresented: $isDeleteStatsConfirmationPresented) {
                Button("Delete", role: .destructive) {
                    isDeleteStatsFinalConfirmationPresented = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your entire reading history will be permanently removed. This cannot be undone.")
            }
            .alert("Are you really sure?", isPresented: $isDeleteStatsFinalConfirmationPresented) {
                Button("Delete Everything", role: .destructive) { statsViewModel.deleteAllStats() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Total listening time, finished books, and all related stats will be erased forever.")
            }
            .sheet(isPresented: $isShareAllExportedPresented) {
                ShareActivityView(activityItems: shareAllExportedItems)
            }
            .onAppear { refreshExportedNoteCount() }
            .task { await monetizationViewModel.onAppear() }
        }
    }

    // MARK: - AudioPig Plus

    private var plusSection: some View {
        Section {
            Label(monetizationViewModel.plusStatusLine, systemImage: "sparkles")
                .foregroundStyle(DS.Color.secondary)

            if monetizationViewModel.showsSubscribeAction {
                Button {
                    Task {
                        await monetizationViewModel.subscribeToPlus()
                        onWatchSettingsChanged?()
                    }
                } label: {
                    if monetizationViewModel.isProcessing {
                        HStack {
                            Text("Subscribe to \(Brand.plusName)")
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.85)
                        }
                    } else if let price = monetizationViewModel.plusDisplayPrice {
                        Text("Subscribe to \(Brand.plusName) — \(price)/mo")
                    } else {
                        Text("Subscribe to \(Brand.plusName)")
                    }
                }
                .disabled(monetizationViewModel.isProcessing)
            }

            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                Label("Manage Subscription", systemImage: "creditcard")
            }

            Button {
                Task {
                    await monetizationViewModel.restorePurchases()
                    onWatchSettingsChanged?()
                }
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
            Text(Brand.plusName)
                .sectionTitle()
        } footer: {
            Text("Smart Rewind is included with Plus. Core playback stays free.")
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

}
