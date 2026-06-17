//
//  OrientationLockController.swift
//  Audiopig
//
//  Applies the user's portrait orientation lock preference at runtime.
//

import UIKit

@MainActor
final class OrientationLockController {
    static let shared = OrientationLockController()

    private(set) var isLocked = false

    private init() {}

    var supportedOrientations: UIInterfaceOrientationMask {
        isLocked ? .portrait : .all
    }

    func setLocked(_ locked: Bool) {
        guard isLocked != locked else { return }
        isLocked = locked
        applyGeometryUpdate()
    }

    private func applyGeometryUpdate() {
        guard let windowScene = activeWindowScene else { return }

        let orientations = supportedOrientations
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }

        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLockController.shared.supportedOrientations
    }
}
