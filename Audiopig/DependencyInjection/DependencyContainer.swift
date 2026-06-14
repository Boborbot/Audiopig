//
//  DependencyContainer.swift
//  Audiopig
//

import Foundation
import SwiftData

/// Central registry for service protocols consumed by ViewModels.
@MainActor
final class DependencyContainer {
    static var shared: DependencyContainer?

    let libraryManager: any LibraryManagerProtocol
    let audioEngine: any AudioEngineProtocol
    let modelContainer: ModelContainer
    let appSettings: AppSettings
    let appIconManager: AppIconManager

    init(
        libraryManager: any LibraryManagerProtocol,
        audioEngine: any AudioEngineProtocol,
        modelContainer: ModelContainer,
        appSettings: AppSettings = AppSettings(),
        appIconManager: AppIconManager
    ) {
        self.libraryManager = libraryManager
        self.audioEngine = audioEngine
        self.modelContainer = modelContainer
        self.appSettings = appSettings
        self.appIconManager = appIconManager
    }

    /// Registers the global container. Call once during app launch after concrete services are wired.
    static func bootstrap(
        libraryManager: any LibraryManagerProtocol,
        audioEngine: any AudioEngineProtocol,
        modelContainer: ModelContainer,
        appSettings: AppSettings = AppSettings(),
        appIconManager: AppIconManager
    ) {
        shared = DependencyContainer(
            libraryManager: libraryManager,
            audioEngine: audioEngine,
            modelContainer: modelContainer,
            appSettings: appSettings,
            appIconManager: appIconManager
        )
    }

    /// Returns the bootstrapped container or triggers a precondition failure.
    static func requireShared() -> DependencyContainer {
        guard let shared else {
            preconditionFailure("DependencyContainer.bootstrap(...) must be called before accessing shared dependencies.")
        }
        return shared
    }
}
