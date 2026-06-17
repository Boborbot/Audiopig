//
//  WatchSettingsView.swift
//  AudiopigWatch
//

import SwiftUI

struct WatchSettingsView: View {
    @ObservedObject var playerViewModel: WatchPlayerViewModel

    init(playerViewModel: WatchPlayerViewModel) {
        _playerViewModel = ObservedObject(wrappedValue: playerViewModel)
    }

    var body: some View {
        List {
            Section {
                Toggle(isOn: gesturesBinding) {
                    Text("Artwork skip gestures")
                        .font(.caption)
                }
                .tint(WDS.Color.coral)
            } footer: {
                Text("Double-tap skips forward; triple-tap skips back on the player artwork zone.")
                    .font(.caption2)
            }
        }
        .navigationTitle("Settings")
    }

    private var gesturesBinding: Binding<Bool> {
        Binding(
            get: { playerViewModel.artworkSkipGesturesEnabled },
            set: { newValue in
                playerViewModel.artworkSkipGesturesEnabled = newValue
                Task {
                    _ = await playerViewModel.sendArtworkGesturesSetting(newValue)
                }
            }
        )
    }
}
