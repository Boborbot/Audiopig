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

    private let container: DependencyContainer
    private let libraryViewModel: LibraryViewModel
    private let statsViewModel: StatsViewModel

    init() {
        do {
            let modelContainer  = try AudiopigModelContainer.make()
            let libraryManager  = try LibraryManager()
            let audioEngine     = try AudioEngine()

            let dc = DependencyContainer(
                libraryManager: libraryManager,
                audioEngine: audioEngine,
                modelContainer: modelContainer
            )
            DependencyContainer.shared = dc
            self.container = dc
            self.libraryViewModel = LibraryViewModel(
                modelContext: dc.modelContainer.mainContext,
                libraryManager: dc.libraryManager,
                audioEngine: dc.audioEngine,
                appSettings: dc.appSettings
            )
            self.statsViewModel = StatsViewModel(
                modelContext: dc.modelContainer.mainContext
            )
        } catch {
            fatalError("Audiopig failed to initialise core services: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(
                libraryViewModel: libraryViewModel,
                appSettings: container.appSettings,
                statsViewModel: statsViewModel
            )
            .modelContainer(container.modelContainer)
            .preferredColorScheme(container.appSettings.appearance.colorScheme)
        }
    }
}
