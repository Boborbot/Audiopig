//
//  EQPresetPicker.swift
//  Audiopig
//

import SwiftUI

struct EQPresetPicker: View {
    let presets: [SpeechEQPreset]
    let activePresetID: String
    var isEQEnabled: Bool = true
    var isDisabled: Bool = false
    let onSelect: (String) -> Void

    private var selectablePresets: [SpeechEQPreset] {
        presets.filter { $0.id != SpeechEQPreset.off.id }
    }

    private var scrollCategories: [SpeechEQCategory] {
        SpeechEQCategory.allCases.filter { $0 != .neutral }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(scrollCategories, id: \.self) { category in
                let categoryPresets = selectablePresets.filter { $0.category == category }
                if !categoryPresets.isEmpty {
                    categoryCarousel(
                        title: category.title,
                        category: category,
                        presets: categoryPresets
                    )
                }
            }
        }
    }

    private func categoryCarousel(title: String, category: SpeechEQCategory, presets: [SpeechEQPreset]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Group {
                if category.showsMusicNote {
                    Label(title, systemImage: "music.note")
                } else {
                    Text(title)
                }
            }
            .font(DS.Typography.sectionHeader)
            .foregroundStyle(DS.Color.primary)
            .accessibilityAddTraits(.isHeader)

            GeometryReader { geometry in
                let tileWidth = geometry.size.width * Layout.tileWidthRatio

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(presets) { preset in
                            EQPresetTile(
                                preset: preset,
                                isActive: isEQEnabled && preset.id == activePresetID,
                                isDisabled: isDisabled || !isEQEnabled,
                                onSelect: { onSelect(preset.id) }
                            )
                            .frame(width: tileWidth, height: geometry.size.height)
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
            .frame(height: Layout.carouselHeight)
        }
        .padding(DS.Spacing.md)
        .floatingPanel()
    }
}

// MARK: - Layout

private enum Layout {
    static let carouselHeight: CGFloat = 67
    static let tileWidthRatio: CGFloat = 0.4
    static let titleFont: Font = .system(size: 15, weight: .semibold, design: .rounded)
    static let titleLineSpacing: CGFloat = 1
}

// MARK: - Preset Tile

private struct EQPresetTile: View {
    let preset: SpeechEQPreset
    let isActive: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    private var titleLines: (first: String, second: String) {
        preset.tileTitleLines
    }

    var body: some View {
        let button = Button(action: onSelect) {
            tileContent
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isActive ? .isSelected : [])

        if let accessibilityHint {
            button.accessibilityHint(accessibilityHint)
        } else {
            button
        }
    }

    private var tileContent: some View {
        titleBlock
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(isActive ? DS.Color.coral : DS.Color.secondarySurface)
            }
            .opacity(isDisabled ? 0.45 : 1)
    }

    private var titleBlock: some View {
        VStack(spacing: Layout.titleLineSpacing) {
            Text(titleLines.first)
                .font(Layout.titleFont)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .foregroundStyle(isActive ? .white : DS.Color.primary)

            if !titleLines.second.isEmpty {
                Text(titleLines.second)
                    .font(Layout.titleFont)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .foregroundStyle(isActive ? .white : DS.Color.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var accessibilityLabel: String {
        var label = preset.label
        if isActive {
            label += ", selected"
        }
        if preset.category == .musicalScores {
            label += ", for books with musical scores"
        }
        return label
    }

    private var accessibilityHint: String? {
        preset.category == .musicalScores
            ? "For books with musical scores"
            : nil
    }
}
