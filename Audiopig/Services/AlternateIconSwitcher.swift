//
//  AlternateIconSwitcher.swift
//  Audiopig
//
//  Switches the home-screen icon without triggering iOS's default confirmation alert.
//  Presents a zero-size modal briefly so UIKit routes the icon change silently.
//

import UIKit

enum AlternateIconSwitcher {

    /// Changes the app icon. Pass `nil` to restore the primary icon.
    static func setIcon(named iconName: String?, completion: @escaping (Bool) -> Void) {
        guard UIApplication.shared.supportsAlternateIcons else {
            completion(false)
            return
        }

        guard let presenter = topMostViewController() else {
            setIconDirectly(named: iconName, completion: completion)
            return
        }

        let blank = UIViewController()
        blank.view.isHidden = true
        blank.modalPresentationStyle = .custom
        blank.transitioningDelegate = SilentModalTransitioningDelegate.shared

        presenter.present(blank, animated: false) {
            UIApplication.shared.setAlternateIconName(iconName) { error in
                blank.dismiss(animated: false) {
                    completion(error == nil)
                }
            }
        }
    }

    // MARK: - Private

    private static func setIconDirectly(named iconName: String?, completion: @escaping (Bool) -> Void) {
        UIApplication.shared.setAlternateIconName(iconName) { error in
            completion(error == nil)
        }
    }

    private static func topMostViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController

        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - Silent modal presentation

private final class SilentModalTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    static let shared = SilentModalTransitioningDelegate()

    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        SilentPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

private final class SilentPresentationController: UIPresentationController {
    override var frameOfPresentedViewInContainerView: CGRect { .zero }
}
