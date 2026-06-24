//
//  WatchConnectivityBanner.swift
//  AudiopigWatch
//

import SwiftUI

enum WatchConnectivityNoticeKind: Equatable {
    case unreachable
    case setup
    case connecting
    case generic
}

struct WatchConnectivityNotice: Equatable {
    let kind: WatchConnectivityNoticeKind
    let title: String
    let detail: String?

    static func from(_ message: String) -> WatchConnectivityNotice {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = normalized.lowercased()

        if lower.contains("connecting") {
            return WatchConnectivityNotice(kind: .connecting, title: "Connecting to iPhone", detail: nil)
        }
        if lower.contains("install") {
            return WatchConnectivityNotice(
                kind: .setup,
                title: "Install on iPhone",
                detail: "Get \(Brand.displayName) from the App Store on your paired iPhone."
            )
        }
        if lower.contains("open audiopig") || lower.contains("not connected") {
            return WatchConnectivityNotice(
                kind: .unreachable,
                title: "Open \(Brand.displayName) on iPhone",
                detail: "Keep the app open to control playback from your Watch."
            )
        }
        if lower.contains("could not reach")
            || lower.contains("couldn't reach")
            || lower.contains("no response")
            || lower.contains("unavailable on iphone") {
            return WatchConnectivityNotice(
                kind: .unreachable,
                title: "iPhone unavailable",
                detail: "Open \(Brand.displayName) on your iPhone and try again."
            )
        }
        if lower.contains("could not load") {
            return WatchConnectivityNotice(
                kind: .generic,
                title: "Couldn't load book",
                detail: "Try again in a moment."
            )
        }

        return WatchConnectivityNotice(kind: .generic, title: normalized, detail: nil)
    }
}

struct WatchConnectivityBanner: View {
    let notice: WatchConnectivityNotice

    init(message: String) {
        notice = WatchConnectivityNotice.from(message)
    }

    init(notice: WatchConnectivityNotice) {
        self.notice = notice
    }

    var body: some View {
        HStack(alignment: .top, spacing: WDS.Spacing.sm) {
            leadingSymbol
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let detail = notice.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, WDS.Spacing.sm)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var leadingSymbol: some View {
        switch notice.kind {
        case .connecting:
            ProgressView()
                .scaleEffect(0.65)
        default:
            Image(systemName: symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
        }
    }

    private var symbolName: String {
        switch notice.kind {
        case .unreachable:
            "iphone.slash"
        case .setup:
            "arrow.down.app"
        case .connecting:
            "ellipsis"
        case .generic:
            "exclamationmark.circle"
        }
    }

    private var accentColor: Color {
        switch notice.kind {
        case .unreachable, .generic:
            WDS.Color.coral
        case .setup:
            .orange
        case .connecting:
            .secondary
        }
    }

    private var backgroundColor: Color {
        switch notice.kind {
        case .connecting:
            Color.secondary.opacity(0.12)
        default:
            WDS.Color.coral.opacity(0.12)
        }
    }
}
