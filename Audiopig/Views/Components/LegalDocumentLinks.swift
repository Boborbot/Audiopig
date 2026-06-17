//
//  LegalDocumentLinks.swift
//  Audiopig
//

import SwiftUI

/// Subtle Terms + Privacy links for Settings and subscription UI.
struct LegalDocumentLinks: View {

    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: DS.Spacing.xs) {
            Link("Terms of Use", destination: AppSupport.termsOfUseURL)
            Link("Privacy Policy", destination: AppSupport.privacyPolicyURL)
        }
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Color.tertiary)
        .tint(DS.Color.tertiary)
    }
}
