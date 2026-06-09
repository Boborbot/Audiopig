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

    init(
        libraryManager: any LibraryManagerProtocol,
        audioEngine: any AudioEngineProtocol,
        modelContainer: ModelContainer
    ) {
        self.libraryManager = libraryManager
        self.audioEngine = audioEngine
        self.modelContainer = modelContainer
    }

    /// Registers the global container. Call once during app launch after concrete services are wired.
    static func bootstrap(
        libraryManager: any LibraryManagerProtocol,
        audioEngine: any AudioEngineProtocol,
        modelContainer: ModelContainer
    ) {
        shared = DependencyContainer(
            libraryManager: libraryManager,
            audioEngine: audioEngine,
            modelContainer: modelContainer
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
