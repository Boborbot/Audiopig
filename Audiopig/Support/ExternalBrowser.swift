//
//  ExternalBrowser.swift
//  Audiopig
//
//  Opens http(s) URLs in the system browser instead of handing off to app universal links.
//

import UIKit

enum ExternalBrowser {

    /// Opens the URL in Safari (or the user's default browser), bypassing universal-link app handoff.
    @MainActor
    static func open(_ url: URL) {
        UIApplication.shared.open(url, options: [.universalLinksOnly: false])
    }
}
