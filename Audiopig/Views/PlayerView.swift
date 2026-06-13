//
//  PlayerView.swift
//  Audiopig
//

import SwiftUI

struct PlayerView: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            // Ambient blurred cover art fills the entire background
            Color.clear
                .playerBackground(image: viewModel.coverImage)

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: DS.Spacing.xl)
                    artworkSection
                    titleSection
                    controlsPanel
                    Spacer().frame(height: DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.playerH)
            }
        }
        .sheet(isPresented: $viewModel.isChaptersPresented) {
            ChaptersListView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isBookmarksPresented) {
            BookmarksListView(viewModel: viewModel)
        }
    }

    // MARK: - Artwork

    private var artworkSection: some View {
        Group {
            if let uiImage = viewModel.coverImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .playerCoverArtClip()
            } else {
                artworkPlaceholder
            }
        }
        .applyShadows(DS.Shadow.coverArt)
        .padding(.top, DS.Spacing.sm)
        .scaleEffect(viewModel.playbackState == .playing ? 1.0 : 0.94)
        .animation(DS.Animation.reveal, value: viewModel.playbackState == .playing)
    }

    private var artworkPlaceholder: some View {
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
                .aspectRatio(1, contentMode: .fit)

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

    private var controlsPanel: some View {
        VStack(spacing: 0) {
            // Hairline separator between title and controls
            Rectangle()
                .fill(DS.Color.separator.opacity(0.4))
                .frame(height: 0.5)
                .padding(.horizontal, DS.Spacing.xl)

            scrubberSection
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.lg)

            controlsSection
                .padding(.top, DS.Spacing.lg + DS.Spacing.sm)

            bottomRow
                .padding(.top, DS.Spacing.lg + DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.lg)
        }
        .padding(.top, DS.Spacing.lg)
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

            Spacer()

            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: "goforward.\(viewModel.skipForwardIntervalSeconds)")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(DS.Color.primary)
            }
            .buttonStyle(DS.ButtonStyle.transport)

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

    // MARK: - Speed Menu

    private var speedMenu: some View {
        Menu {
            ForEach(PlayerViewModel.availableSpeeds, id: \.self) { speed in
                Button {
                    viewModel.setSpeed(speed)
                } label: {
                    let label = speed.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(speed))×"
                        : String(format: "%.2g×", speed)
                    if speed == viewModel.playbackSpeed {
                        Label(label, systemImage: "checkmark")
                    } else {
                        Text(label)
                    }
                }
            }
        } label: {
            Text(viewModel.speedLabel)
                .pillAppearance()
        }
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
    }

    // MARK: - Bookmarks Button

    private var bookmarksButton: some View {
        Button {
            viewModel.isBookmarksPresented = true
        } label: {
            Image(systemName: "bookmark")
                .pillAppearance()
        }
        .buttonStyle(.plain)
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
    }
}
