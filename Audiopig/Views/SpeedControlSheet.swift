//
//  SpeedControlSheet.swift
//  Audiopig
//

import SwiftUI

struct SpeedControlSheet: View {
    let title: String
    @Binding var speed: Float
    var presets: [Float] = []
    var onSpeedChanged: (() -> Void)?

    private var showsPresets: Bool { !presets.isEmpty }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            header

            sliderRow
                .padding(.horizontal, DS.Spacing.md)

            if showsPresets {
                presetRow
                    .padding(.horizontal, DS.Spacing.md)
            }
        }
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass()
        .presentationDetents([showsPresets ? .fraction(0.33) : .fraction(0.25)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(title)
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(DS.Color.primary)

            Spacer()

            Text(speedLabel)
                .font(DS.Typography.controlLabel.monospacedDigit())
                .foregroundStyle(DS.Color.coral)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var speedLabel: String {
        WatchSpeedRange.formatLabel(speed)
    }

    // MARK: - Slider Row

    private var sliderRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            stepButton(systemName: "minus") {
                adjustSpeed(by: -WatchSpeedRange.step)
            }
            .accessibilityLabel("Decrease speed")

            Slider(
                value: sliderBinding,
                in: Double(WatchSpeedRange.min)...Double(WatchSpeedRange.max),
                step: Double(WatchSpeedRange.step)
            )
            .tint(DS.Color.coral)
            .accessibilityLabel("Playback speed")
            .accessibilityValue(speedLabel)

            stepButton(systemName: "plus") {
                adjustSpeed(by: WatchSpeedRange.step)
            }
            .accessibilityLabel("Increase speed")
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { Double(speed) },
            set: { setSpeed(Float($0)) }
        )
    }

    // MARK: - Preset Row

    private var presetRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(presets, id: \.self) { preset in
                Button {
                    setSpeed(preset)
                } label: {
                    Text(WatchSpeedRange.formatLabel(preset))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DS.ButtonStyle.pill(isActive: isPresetActive(preset)))
                .accessibilityAddTraits(isPresetActive(preset) ? .isSelected : [])
            }
        }
    }

    // MARK: - Actions

    private func setSpeed(_ newSpeed: Float) {
        let normalized = WatchSpeedRange.normalized(newSpeed)
        guard normalized != speed else { return }
        speed = normalized
        onSpeedChanged?()
    }

    private func adjustSpeed(by delta: Float) {
        let stepCount = Int((delta / WatchSpeedRange.step).rounded())
        setSpeed(WatchSpeedRange.adjusted(speed, byStepCount: stepCount))
    }

    private func isPresetActive(_ preset: Float) -> Bool {
        abs(speed - preset) < WatchSpeedRange.step / 2
    }

    // MARK: - Step Button

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
