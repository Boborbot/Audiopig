//
//  PlayerView.swift
//  Audiopig
//

import SwiftUI

struct PlayerView: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var paywallViewModel: PaywallViewModel?

    var body: some View {
        ZStack(alignment: .top) {
            // Ambient blurred cover art fills the entire background
            Color.clear
                .playerBackground(image: viewModel.coverImage)

            GeometryReader { geometry in
                let metrics = PlayerLayoutMetrics(geometry: geometry)
                if metrics.isLandscape {
                    landscapeLayout(metrics: metrics, geometry: geometry)
                } else {
                    portraitLayout(metrics: metrics, geometry: geometry)
                }
            }
        }
        .sheet(isPresented: $viewModel.isChaptersPresented) {
            ChaptersListView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isBookmarksPresented) {
            BookmarksListView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.pendingNewBookmark) { bookmark in
            BookmarkEditView(viewModel: viewModel, bookmark: bookmark)
        }
        .sheet(isPresented: $viewModel.isSpeedSheetPresented) {
            PlaybackSpeedSheet(viewModel: viewModel)
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

    // MARK: - Layout

    @ViewBuilder
    private func portraitLayout(metrics: PlayerLayoutMetrics, geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: DS.Spacing.sm)

            artworkSection(width: metrics.artworkWidth, height: metrics.artworkHeight)

            titleSection
                .layoutPriority(1)

            controlsPanel()
                .layoutPriority(1)

            Spacer(minLength: DS.Spacing.sm)
        }
        .padding(.horizontal, metrics.horizontalPadding)
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
            Spacer(minLength: DS.Spacing.sm)

            artworkSection(width: metrics.artworkWidth, height: metrics.artworkHeight)

            titleSection

            Spacer(minLength: DS.Spacing.sm)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .frame(width: metrics.columnWidth, height: metrics.screenSize.height)
    }

    private func controlsColumn(metrics: PlayerLayoutMetrics) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: DS.Spacing.sm)

            controlsPanel(compact: true)

            Spacer(minLength: DS.Spacing.sm)
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
        .scaleEffect(viewModel.playbackState == .playing ? 1.0 : 0.94)
        .animation(DS.Animation.reveal, value: viewModel.playbackState == .playing)
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

    private var titleSection: some View {
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
        .padding(.top, DS.Spacing.lg)
    }

    // MARK: - Controls (laid directly on the glass surface)

    private func controlsPanel(compact: Bool = false) -> some View {
        let sectionGap = compact ? DS.Spacing.sm : DS.Spacing.md + DS.Spacing.sm
        let panelTop = compact ? DS.Spacing.sm : DS.Spacing.md
        let lullBottom = compact ? DS.Spacing.sm : DS.Spacing.md

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

            lullAnalysisSection(compact: compact)
                .padding(.top, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, lullBottom)
        }
        .padding(.top, panelTop)
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
            .tint(DS.Color.coral)
            .accessibilityLabel("Playback position")
            .accessibilityValue(viewModel.scrubDisplayCurrentTime)

            HStack {
                Text(viewModel.scrubDisplayCurrentTime)
                    .timestampStyle()

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
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Speed Button

    private var speedMenu: some View {
        Button {
            viewModel.isSpeedSheetPresented = true
        } label: {
            Text(viewModel.speedLabel)
                .pillAppearance()
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
                .pillAppearance()
        }
        .buttonStyle(.plain)
        .disabled(viewModel.chapters.isEmpty)
        .accessibilityLabel("Chapters")
    }

    // MARK: - Bookmarks Button

    private var bookmarksButton: some View {
        Button {
            viewModel.addBookmarkForEditing()
        } label: {
            Image(systemName: "bookmark")
                .pillAppearance()
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
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
            .pillAppearance(isActive: viewModel.sleepTimerOption != .off)
        }
        .accessibilityLabel(viewModel.sleepTimerOption == .off
            ? "Sleep timer, off"
            : "Sleep timer, \(viewModel.sleepTimerLabel)"
        )
    }

    // MARK: - Lull Analysis Section

    @ViewBuilder
    private func lullAnalysisSection(compact: Bool) -> some View {
        let pillPadding: CGFloat = compact ? 10 : 14

        switch viewModel.lullAnalysisState {
        case .idle:
            Button {
                viewModel.analyzeLulls()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.and.magnifyingglass")
                    Text("Find Paragraph Breaks")
                }
                .frame(maxWidth: .infinity)
                .pillAppearance(verticalPadding: pillPadding)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isActive)

        case .analyzing:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Analyzing…")
            }
            .frame(maxWidth: .infinity)
            .pillAppearance(verticalPadding: pillPadding)

        case .results(let lulls):
            VStack(spacing: DS.Spacing.sm) {
                if lulls.isEmpty {
                    Text("No breaks found")
                        .frame(maxWidth: .infinity)
                        .pillAppearance(verticalPadding: pillPadding)
                } else if let lull = lulls.first {
                    Button {
                        viewModel.seekToLull(lull)
                    } label: {
                        Text(viewModel.lullLabel(for: lull))
                            .frame(maxWidth: .infinity)
                            .pillAppearance(isActive: true, verticalPadding: pillPadding)
                    }
                    .buttonStyle(.plain)
                }

                // Secondary row: cancel and re-analyze.
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
                        viewModel.lookAgainLulls()
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
    let isLandscape: Bool
    let artworkOnLeading: Bool
    let artworkWidth: CGFloat
    let artworkHeight: CGFloat
    let columnWidth: CGFloat
    let horizontalPadding: CGFloat
    let screenSize: CGSize

    init(geometry: GeometryProxy) {
        let size = geometry.size
        let padding = DS.Spacing.playerH
        isLandscape = size.width > size.height
        horizontalPadding = padding
        screenSize = size
        artworkOnLeading = geometry.safeAreaInsets.leading >= geometry.safeAreaInsets.trailing

        if isLandscape {
            columnWidth = size.width / 2
            let columnInner = columnWidth - (padding * 2)
            artworkWidth = columnInner
            artworkHeight = min(columnInner, size.height * 0.62)
        } else {
            columnWidth = size.width
            let contentWidth = size.width - (padding * 2)
            artworkWidth = contentWidth
            artworkHeight = contentWidth
        }
    }
}
