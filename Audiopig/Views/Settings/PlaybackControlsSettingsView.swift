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
    private static let smartRewindFarStartOptions: [TimeInterval] = stride(from: 5, through: 60, by: 5).map { TimeInterval($0 * 60) }
    private static let smartRewindFarEndOptions: [TimeInterval] = stride(from: 1, through: 30, by: 1).map { TimeInterval($0 * 60) }
    private static let smartRewindNearStartOptions: [TimeInterval] = [30, 45, 60, 90, 120, 180, 240, 300, 420, 600, 900]
    private static let smartRewindNearEndOptions: [TimeInterval] = [0, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 300]

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
                Picker("Look Far — from", selection: $settings.smartRewindFarStartOffset) {
                    ForEach(Self.smartRewindFarStartOptions, id: \.self) { seconds in
                        Text(smartRewindOffsetLabel(seconds)).tag(seconds)
                    }
                }
                .tint(DS.Color.coral)

                Picker("Look Far — to", selection: $settings.smartRewindFarEndOffset) {
                    ForEach(Self.smartRewindFarEndOptions, id: \.self) { seconds in
                        Text(smartRewindOffsetLabel(seconds)).tag(seconds)
                    }
                }
                .tint(DS.Color.coral)

                Picker("Look Near — from", selection: $settings.smartRewindNearStartOffset) {
                    ForEach(Self.smartRewindNearStartOptions, id: \.self) { seconds in
                        Text(smartRewindOffsetLabel(seconds)).tag(seconds)
                    }
                }
                .tint(DS.Color.coral)

                Picker("Look Near — to", selection: $settings.smartRewindNearEndOffset) {
                    ForEach(Self.smartRewindNearEndOptions, id: \.self) { seconds in
                        if seconds == 0 {
                            Text("Now").tag(seconds)
                        } else {
                            Text(smartRewindOffsetLabel(seconds)).tag(seconds)
                        }
                    }
                }
                .tint(DS.Color.coral)
            } header: {
                Text("Smart Rewind")
                    .sectionTitle()
            } footer: {
                Text("Times are measured before your current position. Look Far searches further back; Look Near focuses on the last few minutes.")
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

    private func smartRewindOffsetLabel(_ seconds: TimeInterval) -> String {
        if seconds >= 60 {
            let minutes = Int(seconds / 60)
            return minutes == 1 ? "1 min ago" : "\(minutes) min ago"
        }
        return "\(Int(seconds))s ago"
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
