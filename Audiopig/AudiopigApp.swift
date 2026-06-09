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
        } catch {
            fatalError("Audiopig failed to initialise core services: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(
                libraryViewModel: LibraryViewModel(
                    modelContext: container.modelContainer.mainContext,
                    libraryManager: container.libraryManager,
                    audioEngine: container.audioEngine
                )
            )
            .modelContainer(container.modelContainer)
        }
    }
}
