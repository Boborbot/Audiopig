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
                artworkViewModePicker
            } footer: {
                Text("Show cover art with transport controls on the Watch player. \(Brand.plusName) required.")
                    .font(.caption2)
            }

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

            Section {
                Toggle(isOn: findBreaksHiddenBinding) {
                    Text("Hide Find Breaks")
                        .font(.caption)
                }
                .tint(WDS.Color.coral)
            } footer: {
                Text("Turn off to show Find Breaks on the player controls.")
                    .font(.caption2)
            }

            Section("About") {
                Label(Self.versionLabel, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    private static var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = info?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (\(build))"
    }

    private var artworkViewModePicker: some View {
        Picker("Artwork view", selection: artworkViewModeBinding) {
            ForEach(WatchArtworkViewMode.allCases, id: \.self) { mode in
                Text(mode.watchSettingsLabel).tag(mode)
            }
        }
        .disabled(!playerViewModel.hasWatchArtworkViewAccess)
        .opacity(playerViewModel.hasWatchArtworkViewAccess ? 1 : 0.45)
    }

    private var artworkViewModeBinding: Binding<WatchArtworkViewMode> {
        Binding(
            get: { playerViewModel.watchArtworkViewMode },
            set: { newValue in
                playerViewModel.watchArtworkViewMode = newValue
                Task {
                    _ = await playerViewModel.sendWatchArtworkViewModeSetting(newValue)
                }
            }
        )
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

    private var findBreaksHiddenBinding: Binding<Bool> {
        Binding(
            get: { playerViewModel.findBreaksButtonHidden },
            set: { hidden in
                playerViewModel.findBreaksButtonHidden = hidden
                Task {
                    _ = await playerViewModel.sendFindBreaksButtonHiddenSetting(hidden)
                }
            }
        )
    }
}
