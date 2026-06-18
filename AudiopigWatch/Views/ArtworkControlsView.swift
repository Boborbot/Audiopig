//
//  ArtworkControlsView.swift
//  AudiopigWatch
//

import SwiftUI

struct ArtworkControlsView: View {
    @ObservedObject var viewModel: WatchPlayerViewModel
    var isActive: Bool = true

    init(viewModel: WatchPlayerViewModel, isActive: Bool = true) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.isActive = isActive
    }

    var body: some View {
        VStack(spacing: WDS.Spacing.sm) {
            artwork
            transportRow
        }
        .padding(.horizontal, WDS.Spacing.sm)
        .focusable(isActive)
        .task {
            await viewModel.refresh()
        }
    }

    private var artwork: some View {
        Group {
            if let image = viewModel.artworkImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(WDS.Color.placeholder)
                    .overlay {
                        Image(systemName: "headphones")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(viewModel.snapshot.title)
    }

    private var transportRow: some View {
        HStack {
            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: skipBackwardSymbol)
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.togglePlayPause()
            } label: {
                Group {
                    if viewModel.displayState == .loading {
                        ProgressView()
                    } else {
                        Image(systemName: playPauseSymbol)
                            .font(.title2.weight(.semibold))
                    }
                }
                .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: skipForwardSymbol)
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var playPauseSymbol: String {
        viewModel.displayState == .playing ? "pause.fill" : "play.fill"
    }

    private var skipBackwardSymbol: String {
        intervalSymbol(prefix: "gobackward", seconds: viewModel.skipBackwardInterval)
    }

    private var skipForwardSymbol: String {
        intervalSymbol(prefix: "goforward", seconds: viewModel.skipForwardInterval)
    }

    private func intervalSymbol(prefix: String, seconds: Int) -> String {
        let supported = [5, 10, 15, 30, 45, 60, 75, 90]
        if supported.contains(seconds) {
            return "\(prefix).\(seconds)"
        }
        return prefix
    }
}
