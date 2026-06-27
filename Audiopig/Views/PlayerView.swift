//
//  PlayerView.swift
//  Audiopig
//

import SwiftUI

struct PlayerView: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var paywallViewModel: PaywallViewModel?
    @State private var smartRewindScopeSheet: SmartRewindRange?

    private var usesFullScreenPresentation: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Ambient blurred cover art fills the entire background
            Color.clear
                .playerBackground(image: viewModel.coverImage)

            GeometryReader { geometry in
                let metrics = PlayerLayoutMetrics(geometry: geometry)
                Group {
                    if metrics.isLandscape {
                        landscapeLayout(metrics: metrics, geometry: geometry)
                    } else {
                        portraitLayout(metrics: metrics, geometry: geometry)
                    }
                }
                .snapLayoutOnBackgroundTransition()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if usesFullScreenPresentation {
                    playerDismissControl
                }
            }
        }
        .sheet(isPresented: $viewModel.isChaptersPresented) {
            ChaptersListView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isBookmarksPresented) {
            BookmarksListView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isSubtitlesPresented) {
            SubtitlesListView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isSubtitleSearchPresented) {
            SubtitleSearchSheet(viewModel: viewModel)
        }
        .sheet(item: $viewModel.pendingNewBookmark) { bookmark in
            BookmarkEditView(viewModel: viewModel, bookmark: bookmark)
        }
        .sheet(isPresented: $viewModel.isSpeedSheetPresented) {
            PlaybackSpeedSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isEQSheetPresented) {
            AudioEnhancementSheet(viewModel: viewModel)
        }
        .sheet(item: $smartRewindScopeSheet) { range in
            SmartRewindScopeSheet(
                title: range == .far ? "Look Far" : "Look Near",
                scopeKind: range.scopeKind,
                defaultOffsets: viewModel.defaultSmartRewindOffsets(for: range)
            ) { offsets in
                smartRewindScopeSheet = nil
                viewModel.analyzeSmartRewind(range, customOffsets: offsets)
            }
        }
        .sheet(isPresented: $viewModel.isPaywallPresented, onDismiss: { paywallViewModel = nil }) {
            if let paywallViewModel {
                PaywallSheet(viewModel: paywallViewModel)
            }
        }
        .onChange(of: viewModel.isPaywallPresented) { _, presented in
            if presented {
                paywallViewModel = viewModel.makePaywallViewModel()
            }
        }
    }

    // MARK: - Dismiss

    private var playerDismissControl: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(DS.Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close player")
    }

    // MARK: - Layout

    @ViewBuilder
    private func portraitLayout(metrics: PlayerLayoutMetrics, geometry: GeometryProxy) -> some View {
        let content = VStack(spacing: 0) {
            Spacer(minLength: 0)

            artworkSection(width: metrics.artworkWidth, height: metrics.artworkHeight)

            titleSection(compact: metrics.isPad)
                .layoutPriority(1)

            controlsPanel(compact: false)
                .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .frame(width: geometry.size.width)

        Group {
            if metrics.isPad {
                ScrollView(.vertical, showsIndicators: false) {
                    content
                        .frame(minHeight: geometry.size.height - metrics.bottomInset)
                }
            } else {
                content
            }
        }
        .padding(.bottom, metrics.bottomInset)
        .frame(width: geometry.size.width, height: geometry.size.height)
    }

    @ViewBuilder
    private func landscapeLayout(metrics: PlayerLayoutMetrics, geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            if metrics.artworkOnLeading {
                artworkColumn(metrics: metrics)
                columnDivider
                controlsColumn(metrics: metrics)
            } else {
                controlsColumn(metrics: metrics)
                columnDivider
                artworkColumn(metrics: metrics)
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }

    private func artworkColumn(metrics: PlayerLayoutMetrics) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            artworkSection(width: metrics.artworkWidth, height: metrics.artworkHeight)

            titleSection(compact: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .frame(width: metrics.columnWidth, height: metrics.screenSize.height)
    }

    private func controlsColumn(metrics: PlayerLayoutMetrics) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: DS.Spacing.sm)

                controlsPanel(compact: true)

                Spacer(minLength: DS.Spacing.sm)
            }
            .frame(minHeight: metrics.screenSize.height - metrics.bottomInset)
            .padding(.bottom, metrics.bottomInset)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .frame(width: metrics.columnWidth, height: metrics.screenSize.height)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(DS.Color.separator.opacity(0.4))
            .frame(width: 0.5)
    }

    // MARK: - Artwork

    private func artworkSection(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Group {
                if let uiImage = viewModel.coverImage {
                    PlayerCoverArt(
                        image: uiImage,
                        containerWidth: width,
                        containerHeight: height
                    )
                } else {
                    artworkPlaceholder(width: width, height: height)
                }
            }
            .saturation(viewModel.isSubtitlesVisible ? 0.55 : 1.0)
            .brightness(viewModel.isSubtitlesVisible ? -0.08 : 0)
            .animation(DS.Animation.fade, value: viewModel.isSubtitlesVisible)

            if viewModel.isSubtitlesVisible {
                SubtitlesPanel(viewModel: viewModel, style: .artworkOverlay)
                    .artworkSubtitlesScrim()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.coverArt, style: .continuous))
        .scaleEffect(viewModel.playbackState == .playing ? 1.0 : 0.94)
        .animation(DS.Animation.reveal, value: viewModel.playbackState == .playing)
        .animation(DS.Animation.fade, value: viewModel.isSubtitlesVisible)
    }

    private func artworkPlaceholder(width: CGFloat, height: CGFloat) -> some View {
        let accent = viewModel.audiobook?.placeholderColor ?? DS.Color.artworkPlaceholder
        return ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.coverArt, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.85), accent.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "headphones")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))

                if let title = viewModel.audiobook?.title {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, DS.Spacing.lg)
                }
            }
        }
        .frame(width: width, height: height)
        .applyShadows(DS.Shadow.coverArt)
    }

    // MARK: - Title & Author

    private func titleSection(compact: Bool = false) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(viewModel.playerTitle)
                .playerTitleStyle()
                .foregroundStyle(DS.Color.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(viewModel.audiobook?.author ?? "")
                .font(DS.Typography.playerAuthor)
                .foregroundStyle(DS.Color.coral)
                .lineLimit(1)
        }
        .padding(.top, compact ? DS.Spacing.sm : DS.Spacing.md)
    }

    // MARK: - Controls (laid directly on the glass surface)

    private func controlsPanel(compact: Bool = false) -> some View {
        let sectionGap = compact ? DS.Spacing.sm : DS.Spacing.md
        let panelTop = DS.Spacing.sm
        let lullBottom = DS.Spacing.md

        return VStack(spacing: 0) {
            // Hairline separator between title and controls
            Rectangle()
                .fill(DS.Color.separator.opacity(0.4))
                .frame(height: 0.5)
                .padding(.horizontal, DS.Spacing.xl)

            scrubberSection
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.sm)

            if case .failed(let message) = viewModel.playbackState {
                failedStateBanner(message: message)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, compact ? DS.Spacing.sm : DS.Spacing.md)
            }

            controlsSection
                .padding(.top, sectionGap)

            bottomRow
                .padding(.top, sectionGap)

            smartRewindSection(compact: compact)
                .padding(.top, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.md)
                .animation(DS.Animation.standard, value: viewModel.lullAnalysisState)

            if showsSecondaryPillRow {
                secondaryPillRow(compact: compact)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, lullBottom)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Color.clear
                    .frame(height: lullBottom)
            }
        }
        .padding(.top, panelTop)
        .animation(DS.Animation.standard, value: showsSecondaryPillRow)
    }

    // MARK: - Failed State Banner

    private func failedStateBanner(message: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Playback Error")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                .fill(Color.red.opacity(0.80))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Playback error: \(message)")
    }

    // MARK: - Scrubber

    private var scrubberSection: some View {
        VStack(spacing: DS.Spacing.xs) {
            Slider(
                value: $viewModel.scrubPosition,
                in: 0...1,
                onEditingChanged: { editing in
                    if editing {
                        viewModel.beginScrubbing()
                    } else {
                        Task { await viewModel.commitScrub() }
                    }
                }
            )
            .onChange(of: viewModel.scrubPosition) { _, _ in
                if viewModel.isScrubbing {
                    viewModel.previewSubtitlesAtScrubPosition()
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        // Slider sometimes omits onEditingChanged(false) at the 0:00 endpoint.
                        Task { await viewModel.commitScrub() }
                    }
            )
            .tint(DS.Color.coral)
            .accessibilityLabel("Playback position")
            .accessibilityValue(viewModel.scrubDisplayCurrentTime)

            HStack {
                Button {
                    viewModel.toggleLeftTimeDisplay()
                } label: {
                    Text(viewModel.scrubDisplayLeftTime)
                        .timestampStyle()
                        .contentTransition(.numericText())
                        .animation(DS.Animation.fade, value: viewModel.showsRemainingOnLeft)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    viewModel.showsRemainingOnLeft
                        ? "Time remaining at current speed"
                        : "Elapsed time"
                )
                .accessibilityHint("Double tap to toggle between elapsed and remaining time")

                Spacer()

                Text(viewModel.scrubDisplayRemainingTime)
                    .timestampStyle()
            }

            Button {
                viewModel.togglePlaybackDisplayMode()
            } label: {
                Text(viewModel.displayProgressLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.tertiary)
                    .contentTransition(.numericText())
                    .animation(DS.Animation.fade, value: viewModel.displayProgressLabel)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Transport Controls

    private var controlsSection: some View {
        HStack(spacing: 0) {
            Spacer()

            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: "gobackward.\(viewModel.skipBackwardIntervalSeconds)")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(DS.Color.primary)
            }
            .buttonStyle(DS.ButtonStyle.transport)
            .accessibilityLabel("Skip back \(viewModel.skipBackwardIntervalSeconds) seconds")

            Spacer()

            Button {
                viewModel.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(DS.Color.coral)
                        .frame(width: 72, height: 72)
                        .applyShadows(DS.Shadow.playButton)

                    if viewModel.playbackState == .loading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: viewModel.playPauseImage)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .buttonStyle(DS.ButtonStyle.playerControl)
            .accessibilityLabel(viewModel.playbackState == .playing ? "Pause" : "Play")

            Spacer()

            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: "goforward.\(viewModel.skipForwardIntervalSeconds)")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(DS.Color.primary)
            }
            .buttonStyle(DS.ButtonStyle.transport)
            .accessibilityLabel("Skip forward \(viewModel.skipForwardIntervalSeconds) seconds")

            Spacer()
        }
    }

    // MARK: - Bottom Row (speed | chapters | bookmarks | sleep timer)

    private var bottomRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            speedMenu
            chaptersButton
            bookmarksButton
            sleepTimerMenu
        }
        .frame(maxWidth: .infinity)
    }

    /// EQ, Subtitles, and Search hide while Look results expand the control stack.
    private var showsSecondaryPillRow: Bool {
        switch viewModel.lullAnalysisState {
        case .idle, .analyzing:
            return true
        case .results:
            return false
        }
    }

    private func secondaryPillRow(compact: Bool) -> some View {
        let pillPadding: CGFloat = compact ? 10 : 14

        return HStack(spacing: DS.Spacing.sm) {
            eqPillButton(pillPadding: pillPadding)
            subtitlesPillButton(pillPadding: pillPadding)
            searchPillButton(pillPadding: pillPadding)
        }
        .frame(maxWidth: .infinity)
    }

    private func eqPillButton(pillPadding: CGFloat) -> some View {
        Button {
            viewModel.presentEQSheet()
        } label: {
            Image(systemName: "slider.vertical.3")
                .pillAppearance(isActive: viewModel.isAudioEnhancementActive, verticalPadding: pillPadding)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            viewModel.isAudioEnhancementActive
                ? "Equalizer, \(viewModel.activeSpeechEQPreset.label)"
                : "Equalizer"
        )
    }

    private func subtitlesPillButton(pillPadding: CGFloat) -> some View {
        let isTranscribing = viewModel.isSubtitleTranscriptionActive
        let isActive = viewModel.isSubtitlesVisible || isTranscribing

        return Button {
            viewModel.toggleSubtitles()
        } label: {
            Image(systemName: viewModel.isSubtitlesVisible ? "captions.bubble.fill" : "captions.bubble")
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(
                    .variableColor.iterative.dimInactiveLayers,
                    options: .repeating.speed(0.35),
                    isActive: isTranscribing && !reduceMotion
                )
                .pillAppearance(isActive: isActive, verticalPadding: pillPadding)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    Haptics.subtle()
                    viewModel.isSubtitlesPresented = true
                }
        )
        .accessibilityLabel(viewModel.isSubtitlesVisible ? "Hide subtitles" : "Show subtitles")
        .accessibilityHint(
            isTranscribing
                ? "Transcription in progress. Long press for subtitles options."
                : "Long press for subtitles options"
        )
    }

    private func searchPillButton(pillPadding: CGFloat) -> some View {
        Button {
            viewModel.isSubtitleSearchPresented = true
        } label: {
            Image(systemName: "magnifyingglass")
                .pillAppearance(verticalPadding: pillPadding)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search subtitles")
    }

    // MARK: - Speed Button

    private var speedMenu: some View {
        Button {
            viewModel.isSpeedSheetPresented = true
        } label: {
            Text(viewModel.speedLabel)
                .monospacedDigit()
                .playerAccessoryPill(style: .speed)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Playback speed, \(viewModel.speedLabel)")
    }

    // MARK: - Chapters Button

    private var chaptersButton: some View {
        Button {
            viewModel.isChaptersPresented = true
        } label: {
            Image(systemName: "list.bullet")
                .playerAccessoryPill()
        }
        .buttonStyle(.plain)
        .disabled(viewModel.chapters.isEmpty)
        .accessibilityLabel("Chapters")
    }

    // MARK: - Bookmarks Button

    private var bookmarksButton: some View {
        Button {
            Haptics.subtle()
            viewModel.addBookmarkForEditing()
        } label: {
            Image(systemName: "bookmark")
                .playerAccessoryPill()
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    Haptics.subtle()
                    viewModel.isBookmarksPresented = true
                }
        )
        .accessibilityLabel("Bookmarks")
        .accessibilityHint("Tap to add a bookmark. Hold to view all bookmarks.")
    }

    // MARK: - Sleep Timer Menu

    private var sleepTimerMenu: some View {
        Menu {
            Button { viewModel.setSleepTimer(.off) } label: {
                if viewModel.sleepTimerOption == .off {
                    Label("Off", systemImage: "checkmark")
                } else { Text("Off") }
            }
            Divider()
            ForEach([5, 10, 15, 30, 45, 60], id: \.self) { minutes in
                Button { viewModel.setSleepTimer(.minutes(minutes)) } label: {
                    if viewModel.sleepTimerOption == .minutes(minutes) {
                        Label("\(minutes) min", systemImage: "checkmark")
                    } else { Text("\(minutes) min") }
                }
            }
            Divider()
            Button { viewModel.setSleepTimer(.endOfChapter) } label: {
                if viewModel.sleepTimerOption == .endOfChapter {
                    Label("End of Chapter", systemImage: "checkmark")
                } else { Text("End of Chapter") }
            }
        } label: {
            Group {
                if viewModel.sleepTimerOption == .off {
                    Image(systemName: "moon.zzz")
                } else {
                    Text(viewModel.sleepTimerLabel)
                }
            }
            .playerAccessoryPill(
                isActive: viewModel.sleepTimerOption != .off,
                style: viewModel.sleepTimerOption == .off ? .icon : .speed
            )
        }
        .accessibilityLabel(viewModel.sleepTimerOption == .off
            ? "Sleep timer, off"
            : "Sleep timer, \(viewModel.sleepTimerLabel)"
        )
    }

    // MARK: - Smart Rewind Section

    @ViewBuilder
    private func smartRewindSection(compact: Bool) -> some View {
        let pillPadding: CGFloat = compact ? 10 : 14

        switch viewModel.lullAnalysisState {
        case .idle:
            HStack(spacing: DS.Spacing.sm) {
                SmartRewindTriggerButton(
                    title: "Look Far",
                    pillPadding: pillPadding,
                    isEnabled: viewModel.isActive,
                    onTap: { viewModel.analyzeSmartRewind(.far) },
                    onLongPress: { smartRewindScopeSheet = .far }
                )
                SmartRewindTriggerButton(
                    title: "Look Near",
                    pillPadding: pillPadding,
                    isEnabled: viewModel.isActive,
                    onTap: { viewModel.analyzeSmartRewind(.near) },
                    onLongPress: { smartRewindScopeSheet = .near }
                )
            }
            .frame(maxWidth: .infinity)

        case .analyzing:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Analyzing…")
            }
            .frame(maxWidth: .infinity)
            .pillAppearance(verticalPadding: pillPadding)

        case .results(_, let lulls):
            VStack(spacing: DS.Spacing.sm) {
                if lulls.isEmpty {
                    Text("No breaks found")
                        .frame(maxWidth: .infinity)
                        .pillAppearance(verticalPadding: pillPadding)
                } else {
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(lulls) { lull in
                            Button {
                                viewModel.seekToLull(lull)
                            } label: {
                                Text(viewModel.lullLabel(for: lull))
                                    .frame(maxWidth: .infinity)
                                    .pillAppearance(
                                        isActive: lull.id == lulls.first?.id,
                                        verticalPadding: pillPadding
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        viewModel.cancelLullAnalysis()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .pillAppearance()
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.lookAgainSmartRewind()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Look Again")
                        }
                        .frame(maxWidth: .infinity)
                        .pillAppearance()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Layout Metrics

private struct PlayerLayoutMetrics {
    /// Between the original full-size art (1.0) and the tighter iPad pass (0.85).
    private static let artworkScale: CGFloat = 0.925
    /// iPad portrait height cap — between uncapped width-based square and the 0.42 tight cap.
    private static let padPortraitHeightCap: CGFloat = 0.50

    let isLandscape: Bool
    let isPad: Bool
    let artworkOnLeading: Bool
    let artworkWidth: CGFloat
    let artworkHeight: CGFloat
    let columnWidth: CGFloat
    let horizontalPadding: CGFloat
    let bottomInset: CGFloat
    let screenSize: CGSize

    init(geometry: GeometryProxy) {
        let size = geometry.size
        isPad = UIDevice.current.userInterfaceIdiom == .pad
        let padding = isPad ? DS.Spacing.md : DS.Spacing.playerH
        isLandscape = size.width > size.height
        horizontalPadding = padding
        screenSize = size
        artworkOnLeading = geometry.safeAreaInsets.leading >= geometry.safeAreaInsets.trailing
        bottomInset = max(geometry.safeAreaInsets.bottom, DS.Spacing.md)

        if isLandscape {
            columnWidth = size.width / 2
            let columnInner = columnWidth - (padding * 2)
            let baseArtSize = min(columnInner, size.height * 0.62)
            artworkWidth = baseArtSize * Self.artworkScale
            artworkHeight = baseArtSize * Self.artworkScale
        } else {
            columnWidth = size.width
            let contentWidth = size.width - (padding * 2)
            let heightCap = isPad ? size.height * Self.padPortraitHeightCap : .greatestFiniteMagnitude
            let baseArtSize = min(contentWidth, heightCap)
            artworkWidth = baseArtSize * Self.artworkScale
            artworkHeight = baseArtSize * Self.artworkScale
        }
    }
}
