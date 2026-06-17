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
    let watchBridge: any WatchConnectivityBridgeProtocol
    let watchTransferService: any WatchTransferServiceProtocol
    let volumeController: SystemVolumeController
    let monetization: any MonetizationServiceProtocol

    init(
        libraryManager: any LibraryManagerProtocol,
        audioEngine: any AudioEngineProtocol,
        modelContainer: ModelContainer,
        appSettings: AppSettings,
        appIconManager: AppIconManager,
        watchBridge: any WatchConnectivityBridgeProtocol,
        watchTransferService: any WatchTransferServiceProtocol,
        volumeController: SystemVolumeController,
        monetization: any MonetizationServiceProtocol
    ) {
        self.libraryManager = libraryManager
        self.audioEngine = audioEngine
        self.modelContainer = modelContainer
        self.appSettings = appSettings
        self.appIconManager = appIconManager
        self.watchBridge = watchBridge
        self.watchTransferService = watchTransferService
        self.volumeController = volumeController
        self.monetization = monetization
    }

    /// Registers the global container. Call once during app launch after concrete services are wired.
    static func bootstrap(
        libraryManager: any LibraryManagerProtocol,
        audioEngine: any AudioEngineProtocol,
        modelContainer: ModelContainer,
        appSettings: AppSettings,
        appIconManager: AppIconManager,
        watchBridge: any WatchConnectivityBridgeProtocol,
        watchTransferService: any WatchTransferServiceProtocol,
        volumeController: SystemVolumeController,
        monetization: any MonetizationServiceProtocol
    ) {
        shared = DependencyContainer(
            libraryManager: libraryManager,
            audioEngine: audioEngine,
            modelContainer: modelContainer,
            appSettings: appSettings,
            appIconManager: appIconManager,
            watchBridge: watchBridge,
            watchTransferService: watchTransferService,
            volumeController: volumeController,
            monetization: monetization
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
