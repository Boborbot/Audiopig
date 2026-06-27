//
//  PlaybackControlsSettingsView.swift
//  Audiopig
//

import SwiftUI

struct PlaybackControlsSettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var monetizationViewModel: SettingsMonetizationViewModel
    var onWatchSettingsChanged: (() -> Void)?
    var onAudioEnhancementSettingsChanged: (() -> Void)?

    @State private var activeSpeedField: SpeedSettingField?

    private var hasEQAccess: Bool {
        monetizationViewModel.hasAccess(to: .eq)
    }

    private static let skipIntervalOptions: [TimeInterval] = [5, 10, 15, 30, 45, 60]

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
                VStack(spacing: DS.Spacing.md) {
                    SmartRewindScopeSettingsBubble(
                        title: "Look Far",
                        scopeKind: .far,
                        startOffset: $settings.smartRewindFarStartOffset,
                        endOffset: $settings.smartRewindFarEndOffset
                    )

                    SmartRewindScopeSettingsBubble(
                        title: "Look Near",
                        scopeKind: .near,
                        startOffset: $settings.smartRewindNearStartOffset,
                        endOffset: $settings.smartRewindNearEndOffset
                    )
                }
                .settingsPanelRow()
            } header: {
                Text("Smart Rewind")
                    .sectionTitle()
            } footer: {
                Text("Times are measured before your current position. Look Far searches further back; Look Near focuses on the last few minutes.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.tertiary)
            }

            Section {
                AudioEnhancementControls(
                    eqPresetID: $settings.defaultEQPresetID,
                    voiceBoostLevel: $settings.defaultVoiceBoostLevel,
                    scopeLabel: "Default",
                    hasEQAccess: hasEQAccess,
                    onSettingsChanged: onAudioEnhancementSettingsChanged
                )
                .settingsPanelRow()
            } header: {
                Text("Audio Enhancement")
                    .sectionTitle()
            } footer: {
                Text(
                    hasEQAccess
                        ? "Defaults apply when a book has no saved EQ or Voice Boost settings."
                        : "Speech EQ presets are included with AudioPig Plus. Voice Boost is free."
                )
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.tertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Color.canvas.ignoresSafeArea())
        .miniPlayerScrollClearance()
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

// MARK: - Settings Panel Row

private extension View {
    func settingsPanelRow() -> some View {
        listRowInsets(EdgeInsets(
            top: DS.Spacing.xs,
            leading: DS.Spacing.md,
            bottom: DS.Spacing.xs,
            trailing: DS.Spacing.md
        ))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
