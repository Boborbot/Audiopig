//
//  AppSupport.swift
//  Audiopig
//

import Foundation

/// Public support contact and legal URLs for App Store and in-app links.
enum AppSupport {
    static let supportEmail = "audiopigsupport@gmail.com"
    static var supportEmailURL: URL { URL(string: "mailto:\(supportEmail)")! }
    static let privacyPolicyURL = URL(string: "https://boborbot.github.io/Audiopig/privacy-policy.html")!
    static let termsOfUseURL = URL(string: "https://boborbot.github.io/Audiopig/terms.html")!
}
