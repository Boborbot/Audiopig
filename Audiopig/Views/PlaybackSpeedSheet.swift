//
//  PlaybackSpeedSheet.swift
//  Audiopig
//

import SwiftUI

struct PlaybackSpeedSheet: View {
    let viewModel: PlayerViewModel

    var body: some View {
        SpeedControlSheet(
            title: "Playback Speed",
            speed: playbackSpeedBinding,
            presets: viewModel.speedPresets
        )
    }

    private var playbackSpeedBinding: Binding<Float> {
        Binding(
            get: { viewModel.playbackSpeed },
            set: { viewModel.setSpeed($0) }
        )
    }
}
