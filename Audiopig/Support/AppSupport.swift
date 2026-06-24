//
//  AppSupport.swift
//  Audiopig
//

import Foundation

/// Public support contact and legal URLs for App Store and in-app links.
enum AppSupport {
    static let displayName = Brand.displayName
    static let plusName = Brand.plusName
    static let supportEmail = "audiopigsupport@gmail.com"
    static var supportEmailURL: URL { URL(string: "mailto:\(supportEmail)")! }

    /// Public support and legal pages (GitHub Pages on the `AudioPig` org).
    private static let supportSiteBase = "https://audiopig.github.io"
    static let supportSiteURL = URL(string: "\(supportSiteBase)/")!
    static let privacyPolicyURL = URL(string: "\(supportSiteBase)/privacy-policy.html")!
    static let termsOfUseURL = URL(string: "\(supportSiteBase)/terms.html")!
}
