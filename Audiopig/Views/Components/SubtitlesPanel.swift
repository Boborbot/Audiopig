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

    @State private var isFollowingPlayback = true
    @State private var lineFrames: [String: CGRect] = [:]
    /// Visible scroll view bounds in global coordinates.
    @State private var visibleViewportFrame: CGRect = .zero
    @State private var viewportHeight: CGFloat = 0
    @State private var isProgrammaticScroll = false
    @State private var userScrollInProgress = false

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

    private var subtitleScrollState: SubtitleScrollState {
        SubtitleScrollState(
            lineIDs: viewModel.subtitleLines.map(\.id),
            activeID: viewModel.subtitleLines.first(where: \.isActive)?.id
        )
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
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            viewportHeight = geometry.size.height
                            visibleViewportFrame = geometry.frame(in: .global)
                        }
                        .onChange(of: geometry.size.height) { _, height in
                            viewportHeight = height
                        }
                        .onChange(of: geometry.frame(in: .global)) { _, frame in
                            visibleViewportFrame = frame
                        }
                }
            }
            .subtitleScrollInteraction(
                userScrollInProgress: $userScrollInProgress,
                onInteractionEnded: reevaluateFollowMode
            )
            .sensoryFeedback(.success, trigger: copiedSubtitleLineID)
            .sensoryFeedback(.success, trigger: bookmarkedSubtitleLineID)
            .onPreferenceChange(SubtitleLineFramesKey.self) { frames in
                lineFrames = frames
                reevaluateFollowMode()
            }
            .onChange(of: subtitleScrollState) { old, new in
                handleSubtitleScrollChange(from: old, to: new, using: proxy)
            }
            .onChange(of: viewModel.isSubtitlesVisible) { _, visible in
                guard visible else {
                    actionMenuLineID = nil
                    isFollowingPlayback = true
                    return
                }
                isFollowingPlayback = true
                scrollToActiveLine(using: proxy, animated: true)
            }
            .onAppear {
                isFollowingPlayback = true
                scrollToActiveLine(using: proxy, animated: false)
            }
        }
    }

    private func handleSubtitleScrollChange(
        from old: SubtitleScrollState,
        to new: SubtitleScrollState,
        using proxy: ScrollViewProxy
    ) {
        guard viewModel.isSubtitlesVisible, let activeID = new.activeID else { return }

        guard !userScrollInProgress else { return }
        guard shouldAutoCenterOnHighlightChange(previousActiveID: old.activeID) else { return }

        if old.lineIDs != new.lineIDs {
            if compensateWindowSlide(from: old.lineIDs, to: new.lineIDs, using: proxy) {
                return
            }
            if old.activeID != new.activeID {
                scrollToActiveLineOnHighlightChange(using: proxy, activeID: activeID)
            }
            return
        }

        if old.activeID != new.activeID {
            scrollToActiveLineOnHighlightChange(using: proxy, activeID: activeID)
        }
    }

    /// Auto-center only while the previous highlight was still in follow range (on screen, not scrolled away).
    private func shouldAutoCenterOnHighlightChange(previousActiveID: String?) -> Bool {
        guard isFollowingPlayback else { return false }
        guard let previousActiveID else { return true }
        guard isLineWithinFollowRange(previousActiveID) else {
            isFollowingPlayback = false
            return false
        }
        return true
    }

    private func isLineWithinFollowRange(_ lineID: String) -> Bool {
        guard let frame = lineFrames[lineID],
              visibleViewportFrame.height > 0 else { return false }

        guard frame.intersects(visibleViewportFrame) else { return false }

        let distanceFromCenter = abs(frame.midY - visibleViewportFrame.midY)
        return distanceFromCenter <= visibleViewportFrame.height
    }

    /// Keeps on-screen text stable when the cue window slides at its edges.
    @discardableResult
    private func compensateWindowSlide(
        from oldIDs: [String],
        to newIDs: [String],
        using proxy: ScrollViewProxy
    ) -> Bool {
        let removedFromTop = SubtitleCueResolver.slidingWindowTopRemoval(old: oldIDs, new: newIDs)
        if removedFromTop > 0,
           oldIDs.indices.contains(removedFromTop) {
            let anchorID = oldIDs[removedFromTop]
            if let anchor = preservedAnchor(for: anchorID) {
                performProgrammaticScroll {
                    proxy.scrollTo(anchorID, anchor: anchor)
                }
                return true
            }
        }

        let insertedAtTop = SubtitleCueResolver.slidingWindowTopInsertion(old: oldIDs, new: newIDs)
        if insertedAtTop > 0,
           let anchorID = oldIDs.first,
           newIDs.contains(anchorID),
           let anchor = preservedAnchor(for: anchorID) {
            performProgrammaticScroll {
                proxy.scrollTo(anchorID, anchor: anchor)
            }
            return true
        }

        return false
    }

    private func preservedAnchor(for lineID: String) -> UnitPoint? {
        guard viewportHeight > 0,
              let frame = lineFrames[lineID],
              visibleViewportFrame.height > 0 else { return nil }

        let relativeY = (frame.midY - visibleViewportFrame.minY) / viewportHeight
        guard relativeY.isFinite else { return nil }
        return UnitPoint(x: 0.5, y: min(max(relativeY, 0), 1))
    }

    private func scrollToActiveLineOnHighlightChange(
        using proxy: ScrollViewProxy,
        activeID: String
    ) {
        scrollToActiveLine(using: proxy, activeID: activeID, animated: true)
    }

    private func scrollToActiveLine(
        using proxy: ScrollViewProxy,
        activeID: String? = nil,
        animated: Bool
    ) {
        guard viewModel.isSubtitlesVisible else { return }
        let resolvedActiveID = activeID ?? viewModel.subtitleLines.first(where: \.isActive)?.id
        guard let resolvedActiveID else { return }
        guard viewModel.subtitleLines.map(\.id).contains(resolvedActiveID) else { return }

        DispatchQueue.main.async {
            performProgrammaticScroll(animated: animated) {
                proxy.scrollTo(resolvedActiveID, anchor: SubtitleScrollMetrics.centerAnchor)
            }
        }
    }

    private func performProgrammaticScroll(
        animated: Bool = false,
        _ scroll: () -> Void
    ) {
        isProgrammaticScroll = true
        if animated {
            withAnimation(DS.Animation.fade) {
                scroll()
            }
        } else {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                scroll()
            }
        }
        DispatchQueue.main.async {
            isProgrammaticScroll = false
        }
    }

    private func reevaluateFollowMode() {
        guard !isProgrammaticScroll else { return }
        guard let activeID = subtitleScrollState.activeID else { return }

        isFollowingPlayback = isLineWithinFollowRange(activeID)
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
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: SubtitleLineFramesKey.self,
                            value: [
                                line.id: geometry.frame(in: .global)
                            ]
                        )
                    }
                }
                .onTapGesture {
                    if actionMenuLineID != nil {
                        actionMenuLineID = nil
                    } else if line.isActive {
                        viewModel.togglePlayPause()
                    } else {
                        isFollowingPlayback = true
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
        .accessibilityHint(
            line.isActive
                ? "Tap to play or pause. Long press for copy and bookmark."
                : "Tap to jump to this moment. Long press for copy and bookmark."
        )
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

// MARK: - Scroll coordination

private struct SubtitleScrollState: Equatable {
    let lineIDs: [String]
    let activeID: String?
}

private enum SubtitleScrollMetrics {
    static let centerAnchor = UnitPoint(x: 0.5, y: 0.5)
}

private struct SubtitleLineFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

@available(iOS 18.0, *)
private struct SubtitleScrollInteractionModifier: ViewModifier {
    @Binding var userScrollInProgress: Bool
    let onInteractionEnded: () -> Void

    func body(content: Content) -> some View {
        content.onScrollPhaseChange { _, phase in
            switch phase {
            case .interacting, .decelerating:
                userScrollInProgress = true
            case .idle:
                userScrollInProgress = false
                onInteractionEnded()
            case .animating:
                break
            @unknown default:
                break
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func subtitleScrollInteraction(
        userScrollInProgress: Binding<Bool>,
        onInteractionEnded: @escaping () -> Void
    ) -> some View {
        if #available(iOS 18.0, *) {
            modifier(
                SubtitleScrollInteractionModifier(
                    userScrollInProgress: userScrollInProgress,
                    onInteractionEnded: onInteractionEnded
                )
            )
        } else {
            self
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
