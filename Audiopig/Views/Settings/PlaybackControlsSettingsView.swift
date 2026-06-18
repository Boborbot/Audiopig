//
//  PlaybackControlsSettingsView.swift
//  Audiopig
//

import SwiftUI

struct PlaybackControlsSettingsView: View {
    @Bindable var settings: AppSettings
    var onWatchSettingsChanged: (() -> Void)?

    @State private var activeSpeedField: SpeedSettingField?

    private static let skipIntervalOptions: [TimeInterval] = [5, 10, 15, 30, 45, 60]
    private static let lullLookbackOptions: [TimeInterval] = stride(from: 1, through: 15, by: 1).map { TimeInterval($0 * 60) }
    private static let lullSkipRecentOptions: [TimeInterval] = [0, 10, 20, 30, 45, 60, 90, 120]

    var body: some View {
        List {
            Section {
                speedSettingRow(.defaultSpeed, value: settings.defaultSpeed)

                Toggle(isOn: $settings.universalPlaybackSpeedEnabled) {
                    Label("Universal playback speed", systemImage: "globe")
                }
                .tint(DS.Color.coral)
                .onChange(of: settings.universalPlaybackSpeedEnabled) { _, _ in onWatchSettingsChanged?() }

                speedSettingRow(.speedPreset1, value: settings.speedPreset1)
                speedSettingRow(.speedPreset2, value: settings.speedPreset2)
                speedSettingRow(.speedPreset3, value: settings.speedPreset3)

                Picker("Skip Forward", selection: $settings.skipForwardInterval) {
                    ForEach(Self.skipIntervalOptions, id: \.self) { seconds in
                        Text("\(Int(seconds))s").tag(seconds)
                    }
                }
                .tint(DS.Color.coral)
                .onChange(of: settings.skipForwardInterval) { _, _ in onWatchSettingsChanged?() }

                Picker("Skip Backward", selection: $settings.skipBackwardInterval) {
                    ForEach(Self.skipIntervalOptions, id: \.self) { seconds in
                        Text("\(Int(seconds))s").tag(seconds)
                    }
                }
                .tint(DS.Color.coral)
                .onChange(of: settings.skipBackwardInterval) { _, _ in onWatchSettingsChanged?() }
            } header: {
                Text("Playback")
                    .sectionTitle()
            }

            Section {
                Picker("Look back", selection: $settings.lullLookbackWindow) {
                    ForEach(Self.lullLookbackOptions, id: \.self) { seconds in
                        Text("\(Int(seconds / 60)) min").tag(seconds)
                    }
                }
                .tint(DS.Color.coral)

                Picker("Skip recent", selection: $settings.lullSkipRecentWindow) {
                    ForEach(Self.lullSkipRecentOptions, id: \.self) { seconds in
                        if seconds == 0 {
                            Text("Off").tag(seconds)
                        } else {
                            Text("\(Int(seconds))s").tag(seconds)
                        }
                    }
                }
                .tint(DS.Color.coral)
            } header: {
                Text("Paragraph Breaks")
                    .sectionTitle()
            } footer: {
                Text("Controls how far back Find Paragraph Breaks analyzes, and how much recent audio is ignored.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.tertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Color.canvas.ignoresSafeArea())
        .navigationTitle("Playback Controls")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSpeedField) { field in
            SpeedControlSheet(
                title: field.title,
                speed: speedBinding(for: field),
                onSpeedChanged: onWatchSettingsChanged
            )
        }
    }

    // MARK: - Speed Settings

    private func speedSettingRow(_ field: SpeedSettingField, value: Float) -> some View {
        Button {
            activeSpeedField = field
        } label: {
            HStack {
                Text(field.title)
                    .foregroundStyle(DS.Color.primary)
                Spacer()
                Text(WatchSpeedRange.formatLabel(value))
                    .foregroundStyle(DS.Color.secondary)
            }
        }
        .tint(DS.Color.coral)
    }

    private func speedBinding(for field: SpeedSettingField) -> Binding<Float> {
        switch field {
        case .defaultSpeed:
            return $settings.defaultSpeed
        case .speedPreset1:
            return $settings.speedPreset1
        case .speedPreset2:
            return $settings.speedPreset2
        case .speedPreset3:
            return $settings.speedPreset3
        }
    }
}

// MARK: - Speed Setting Field

private enum SpeedSettingField: String, Identifiable {
    case defaultSpeed
    case speedPreset1
    case speedPreset2
    case speedPreset3

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultSpeed: return "Default Speed"
        case .speedPreset1: return "Speed Button 1"
        case .speedPreset2: return "Speed Button 2"
        case .speedPreset3: return "Speed Button 3"
        }
    }
}
