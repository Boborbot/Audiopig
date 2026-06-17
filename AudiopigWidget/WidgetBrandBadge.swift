//
//  WidgetBrandBadge.swift
//  AudiopigWidget
//

import SwiftUI

struct WidgetBrandBadge: View {
    var size: CGFloat = WidgetBrandSpacing.standardBadgeSize

    private var cornerRadius: CGFloat {
        size * 0.25
    }

    var body: some View {
        Image("WidgetAppIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
    }
}

enum WidgetBrandSpacing {
    static let standardBadgeSize: CGFloat = 20
    static let prominentBadgeSize: CGFloat = 34
    static let chartBadgeSize: CGFloat = 36

    static let badgeInset: CGFloat = 10

    /// Top padding for primary content when a prominent badge sits in the top-leading corner.
    static let prominentContentTopPadding: CGFloat = 32
    static let standardContentTopPadding: CGFloat = 22
}
