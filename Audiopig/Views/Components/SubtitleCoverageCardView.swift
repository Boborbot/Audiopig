//
//  SubtitleCoverageCardView.swift
//  Audiopig
//

import SwiftUI

/// Liquid-glass card showing book transcription coverage as a proportional timeline.
struct SubtitleCoverageCardView: View {
    let timeline: SubtitleCoverageTimeline
    let formatTime: (TimeInterval) -> String

    private let trackHeight: CGFloat = 8
    private let runHeight: CGFloat = 6

    private var coveragePercent: Int {
        Int((timeline.coverageFraction * 100).rounded())
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("\(coveragePercent)%")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.Color.coral)
                .monospacedDigit()
                .accessibilityHidden(true)

            timelineBar

            HStack {
                Text(formatTime(0))
                Spacer()
                Text(formatTime(timeline.bookDuration))
            }
            .font(DS.Typography.caption.monospacedDigit())
            .foregroundStyle(DS.Color.secondary)

            if let caption = sectionsCaption {
                Text(caption)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(DS.Spacing.md)
        .floatingPanel()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var timelineBar: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let duration = max(timeline.bookDuration, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DS.Color.secondarySurface)
                    .frame(height: trackHeight)

                ForEach(timeline.runs) { run in
                    let x = run.startTime / duration * width
                    let runWidth = run.duration / duration * width
                    Capsule()
                        .fill(DS.Color.coral)
                        .frame(width: max(0, runWidth), height: runHeight)
                        .offset(x: x)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: trackHeight)
    }

    private var sectionsCaption: String? {
        switch timeline.uncoveredWindowCount {
        case 0:
            return "Entire book transcribed"
        case 1:
            return "1 section still to fill"
        default:
            return "\(timeline.uncoveredWindowCount) sections still to fill"
        }
    }

    private var accessibilityLabel: String {
        let percent = coveragePercent
        switch timeline.uncoveredWindowCount {
        case 0:
            return "Book transcription coverage, \(percent) percent, entire book transcribed"
        case 1:
            return "Book transcription coverage, \(percent) percent, 1 section still to fill"
        default:
            return "Book transcription coverage, \(percent) percent, \(timeline.uncoveredWindowCount) sections still to fill"
        }
    }
}
