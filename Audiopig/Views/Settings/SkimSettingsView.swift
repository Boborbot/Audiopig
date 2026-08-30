//
//  SkimSettingsView.swift
//  Audiopig
//

import SwiftUI

struct SkimSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        List {
            Section {
                Toggle(isOn: $settings.skimEnabled) {
                    Label("Skim", systemImage: "hare.fill")
                }
                .tint(DS.Color.coral)
            } footer: {
                Text("Press and hold cover art in the player to temporarily boost playback speed when you need the book to get on with it.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.tertiary)
            }

            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        Text("Speed")
                            .font(DS.Typography.sectionHeader)
                            .foregroundStyle(DS.Color.primary)

                        Spacer()

                        Text(speedLabel)
                            .font(DS.Typography.controlLabel.monospacedDigit())
                            .foregroundStyle(DS.Color.coral)
                    }

                    sliderRow
                }
                .settingsPanelRow()
                .disabled(!settings.skimEnabled)
                .opacity(settings.skimEnabled ? 1 : 0.45)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Color.canvas.ignoresSafeArea())
        .miniPlayerScrollClearance()
        .navigationTitle("Skim")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var speedLabel: String {
        WatchSpeedRange.formatLabel(settings.skim)
    }

    private var sliderRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            stepButton(systemName: "minus") {
                adjustSpeed(by: -WatchSpeedRange.step)
            }
            .accessibilityLabel("Decrease Skim")

            Slider(
                value: sliderBinding,
                in: Double(WatchSpeedRange.min)...Double(WatchSpeedRange.max),
                step: Double(WatchSpeedRange.step)
            )
            .tint(DS.Color.coral)
            .accessibilityLabel("Skim")
            .accessibilityValue(speedLabel)

            stepButton(systemName: "plus") {
                adjustSpeed(by: WatchSpeedRange.step)
            }
            .accessibilityLabel("Increase Skim")
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { Double(settings.skim) },
            set: { settings.skim = Float($0) }
        )
    }

    private func adjustSpeed(by delta: Float) {
        let stepCount = Int((delta / WatchSpeedRange.step).rounded())
        guard stepCount != 0 else { return }
        settings.skim = WatchSpeedRange.adjusted(settings.skim, byStepCount: stepCount)
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DS.Color.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(UIColor.secondarySystemBackground)))
        }
        .buttonStyle(DS.ButtonStyle.transport)
    }
}

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
