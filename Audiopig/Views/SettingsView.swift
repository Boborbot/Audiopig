//
//  SettingsView.swift
//  Audiopig
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    private static let skipIntervalOptions: [TimeInterval] = [5, 10, 15, 30, 45, 60]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                        .sectionTitle()
                }

                Section {
                    Picker("Default Speed", selection: $settings.defaultSpeed) {
                        ForEach(PlayerViewModel.availableSpeeds, id: \.self) { speed in
                            Text(speedLabel(speed)).tag(speed)
                        }
                    }
                    .tint(DS.Color.coral)

                    Picker("Skip Forward", selection: $settings.skipForwardInterval) {
                        ForEach(Self.skipIntervalOptions, id: \.self) { seconds in
                            Text("\(Int(seconds))s").tag(seconds)
                        }
                    }
                    .tint(DS.Color.coral)

                    Picker("Skip Backward", selection: $settings.skipBackwardInterval) {
                        ForEach(Self.skipIntervalOptions, id: \.self) { seconds in
                            Text("\(Int(seconds))s").tag(seconds)
                        }
                    }
                    .tint(DS.Color.coral)
                } header: {
                    Text("Playback")
                        .sectionTitle()
                }

                Section {
                    Label("Version 1.0", systemImage: "info.circle")
                        .foregroundStyle(DS.Color.secondary)
                } header: {
                    Text("About")
                        .sectionTitle()
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.Color.canvas.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .coralNavigationBanner()
        }
    }

    private func speedLabel(_ speed: Float) -> String {
        speed.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(speed))×"
            : String(format: "%.2g×", speed)
    }
}
