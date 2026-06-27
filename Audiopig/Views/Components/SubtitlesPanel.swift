//
//  SubtitlesPanel.swift
//  Audiopig
//

import SwiftUI
import UIKit

struct SubtitlesPanel: View {

    @State private var copiedSubtitleLineID: String?
    @State private var bookmarkedSubtitleLineID: String?
    @State private var actionMenuLineID: String?

    enum Style {
        /// Frosted overlay on cover art — light text on dark scrim.
        case artworkOverlay
    }

    @Bindable var viewModel: PlayerViewModel
    var style: Style = .artworkOverlay

    private var primaryTextColor: Color {
        style == .artworkOverlay ? .white : DS.Color.primary
    }

    private var secondaryTextColor: Color {
        style == .artworkOverlay ? Color.white.opacity(0.72) : DS.Color.secondary
    }

    private var inactiveLineColor: Color {
        style == .artworkOverlay ? Color.white.opacity(0.42) : DS.Color.tertiary
    }

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            switch viewModel.subtitlePresentation {
            case .hidden:
                EmptyView()
            case .unavailable:
                messageBlock(
                    title: "Subtitles Unavailable",
                    body: "Live subtitles require iOS 26 or later.",
                    systemImage: "captions.bubble"
                )
            case .needsGeneration:
                needsGenerationContent
            case .loading(let message):
                loadingContent(message: message)
            case .ready, .partial:
                subtitlesScrollContent
            case .failed(let message):
                failedContent(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
    }

    // MARK: - Ready state

    private var subtitlesScrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: DS.Spacing.md) {
                    Color.clear.frame(height: DS.Spacing.md)

                    ForEach(viewModel.subtitleLines) { line in
                        subtitleLineRow(line)
                            .id(line.id)
                    }

                    Color.clear.frame(height: DS.Spacing.md)
                }
                .padding(.horizontal, DS.Spacing.sm)
            }
            .contentMargins(.top, DS.Spacing.lg, for: .scrollContent)
            .contentMargins(.bottom, DS.Spacing.lg, for: .scrollContent)
            .scrollClipDisabled(actionMenuLineID != nil)
            .sensoryFeedback(.success, trigger: copiedSubtitleLineID)
            .sensoryFeedback(.success, trigger: bookmarkedSubtitleLineID)
            .onChange(of: viewModel.subtitleLines.map(\.id)) { _, ids in
                scrollToActiveLine(using: proxy, activeIDs: ids)
            }
            .onChange(of: viewModel.subtitleLines.first(where: \.isActive)?.id) { _, _ in
                scrollToActiveLine(using: proxy)
            }
            .onChange(of: viewModel.isSubtitlesVisible) { _, visible in
                guard visible else {
                    actionMenuLineID = nil
                    return
                }
                scrollToActiveLine(using: proxy)
            }
            .onAppear {
                scrollToActiveLine(using: proxy)
            }
        }
    }

    private func scrollToActiveLine(
        using proxy: ScrollViewProxy,
        activeIDs: [String]? = nil
    ) {
        guard viewModel.isSubtitlesVisible else { return }
        let ids = activeIDs ?? viewModel.subtitleLines.map(\.id)
        guard let activeID = viewModel.subtitleLines.first(where: \.isActive)?.id else { return }
        guard ids.contains(activeID) else { return }

        DispatchQueue.main.async {
            withAnimation(DS.Animation.fade) {
                proxy.scrollTo(activeID, anchor: UnitPoint(x: 0.5, y: 0.42))
            }
        }
    }

    private func subtitleLineRow(_ line: PlayerViewModel.SubtitleLineItem) -> some View {
        ZStack(alignment: .top) {
            Text(line.text)
                .font(DS.Typography.subtitle(viewModel.subtitleFont, active: line.isActive))
                .foregroundStyle(line.isActive ? DS.Color.coral : inactiveLineColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xs)
                .contentShape(Rectangle())
                .onTapGesture {
                    if actionMenuLineID != nil {
                        actionMenuLineID = nil
                    } else {
                        viewModel.seekToSubtitle(at: line.startTime)
                    }
                }
                .onLongPressGesture(minimumDuration: 0.45) {
                    Haptics.subtle()
                    withAnimation(DS.Animation.snappy) {
                        actionMenuLineID = line.id
                    }
                }

            if actionMenuLineID == line.id {
                SubtitleLineActionBubble(
                    onCopy: {
                        copySubtitleLine(line)
                        actionMenuLineID = nil
                    },
                    onBookmark: {
                        bookmarkSubtitleLine(line)
                        actionMenuLineID = nil
                    }
                )
                .offset(y: -48)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .zIndex(actionMenuLineID == line.id ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to jump to this moment. Long press for copy and bookmark.")
        .accessibilityAction(named: "Copy") {
            copySubtitleLine(line)
        }
        .accessibilityAction(named: "Add Bookmark") {
            bookmarkSubtitleLine(line)
        }
    }

    private func copySubtitleLine(_ line: PlayerViewModel.SubtitleLineItem) {
        UIPasteboard.general.string = line.text
        copiedSubtitleLineID = line.id
    }

    private func bookmarkSubtitleLine(_ line: PlayerViewModel.SubtitleLineItem) {
        viewModel.addBookmarkFromSubtitle(text: line.text, at: line.startTime)
        bookmarkedSubtitleLineID = line.id
    }

    // MARK: - Generation prompts

    private var needsGenerationContent: some View {
        VStack(spacing: DS.Spacing.md) {
            messageBlock(
                title: "Live Subtitles",
                body: "Generate subtitles near where you are listening.",
                systemImage: "captions.bubble"
            )
            Button {
                viewModel.generateSubtitlesNearPlayhead()
            } label: {
                Text("Generate Near Me")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DS.ButtonStyle.primary())
            Button("Cancel") {
                viewModel.dismissSubtitlesWithoutGenerating()
            }
            .buttonStyle(DS.ButtonStyle.ghost)
        }
    }

    private func loadingContent(message: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            ProgressView()
                .tint(DS.Color.coral)
            Text(message)
                .font(DS.Typography.caption)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
        }
    }

    private func failedContent(message: String) -> some View {
        VStack(spacing: DS.Spacing.md) {
            messageBlock(
                title: "Could Not Generate",
                body: message,
                systemImage: "exclamationmark.triangle"
            )
            Button("Try Again") {
                viewModel.retrySubtitleGeneration()
            }
            .buttonStyle(DS.ButtonStyle.ghost)
        }
    }

    private func messageBlock(title: String, body: String, systemImage: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(DS.Color.coral)
            Text(title)
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(primaryTextColor)
            Text(body)
                .font(DS.Typography.caption)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Line action bubble

private struct SubtitleLineActionBubble: View {
    let onCopy: () -> Void
    let onBookmark: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Button(action: onCopy) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 17, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy")

            Button(action: onBookmark) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 18, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.white)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.black.opacity(0.55))
                        .offset(x: 6, y: 4)
                }
                .frame(width: 40, height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add bookmark")
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xs)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                }
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }
}
