//
//  AudiopigApp.swift
//  Audiopig
//
//  Created by Nitay A. on 08/06/2026.
//

import SwiftUI
import SwiftData

@main
struct AudiopigApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container: DependencyContainer
    private let libraryViewModel: LibraryViewModel
    private let statsViewModel: StatsViewModel
    private let settingsMonetizationViewModel: SettingsMonetizationViewModel

    init() {
        do {
            let modelContainer  = try AudiopigModelContainer.make()
            let libraryManager  = try LibraryManager()
            let audioEngine     = try AudioEngine()
            let appIconManager  = AppIconManager()
            let appSettings     = AppSettings()
            let watchBridge     = WatchConnectivityService()
            let volumeController = SystemVolumeController()
            let monetizationService = StoreKitMonetizationService()
            let watchTransferService = WatchTransferService(watchBridge: watchBridge)
            monetizationService.startTransactionListener()

            let mainContext = modelContainer.mainContext
            let subtitleStore = SubtitleStore(modelContext: mainContext)
            let wholeBookQueue = WholeBookTranscriptionQueueService(
                modelContext: mainContext,
                subtitleStore: subtitleStore,
                transcriptionService: SubtitleTranscriptionService(),
                monetization: monetizationService,
                localeProvider: { appSettings.subtitleLocaleIdentifier ?? Locale.current.identifier }
            )

            let dc = DependencyContainer(
                libraryManager: libraryManager,
                audioEngine: audioEngine,
                modelContainer: modelContainer,
                appSettings: appSettings,
                appIconManager: appIconManager,
                watchBridge: watchBridge,
                watchTransferService: watchTransferService,
                volumeController: volumeController,
                monetization: monetizationService,
                wholeBookTranscriptionQueue: wholeBookQueue
            )
            DependencyContainer.shared = dc
            watchBridge.activate()
            let libraryVM = LibraryViewModel(
                modelContext: dc.modelContainer.mainContext,
                libraryManager: dc.libraryManager,
                audioEngine: dc.audioEngine,
                appSettings: dc.appSettings,
                appIconManager: dc.appIconManager,
                watchBridge: dc.watchBridge,
                watchTransferService: dc.watchTransferService,
                volumeController: volumeController,
                monetization: dc.monetization,
                wholeBookTranscriptionQueue: wholeBookQueue
            )
            self.container = dc
            self.libraryViewModel = libraryVM
            WidgetPlaybackService.bind(libraryViewModel: libraryVM)
            let statsVM = StatsViewModel(
                modelContext: dc.modelContainer.mainContext
            )
            self.statsViewModel = statsVM
            libraryVM.onReadingStatsChanged = {
                statsVM.refresh()
            }
            self.settingsMonetizationViewModel = SettingsMonetizationViewModel(
                monetization: dc.monetization
            )
            OrientationLockController.shared.setLocked(dc.appSettings.orientationLock)
        } catch {
            fatalError("\(Brand.displayName) failed to initialise core services: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(
                libraryViewModel: libraryViewModel,
                appSettings: container.appSettings,
                statsViewModel: statsViewModel,
                appIconManager: container.appIconManager,
                settingsMonetizationViewModel: settingsMonetizationViewModel
            )
            .modelContainer(container.modelContainer)
            .preferredColorScheme(container.appSettings.appearance.colorScheme)
        }
    }
}
