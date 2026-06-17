//
//  AppIconGalleryThumbnail.swift
//  Audiopig
//
//  Renders achievement or secret-achievement icon previews in the Stats gallery.
//

import SwiftUI

enum AppIconGalleryThumbnailStyle {
    /// Hour-based achievements: icon is always visible; locked state is dimmed with a lock.
    case achievement(progress: Double)
    /// Secret achievements: hidden as a grey question mark until unlocked.
    case secret
}

struct AppIconGalleryThumbnail: View {
    let galleryImageName: String
    let isUnlocked: Bool
    let style: AppIconGalleryThumbnailStyle

    private let size: CGFloat = 64

    private var progress: Double {
        if case .achievement(let progress) = style { return progress }
        return 1
    }

    var body: some View {
        ZStack {
            switch style {
            case .achievement:
                achievementThumbnail
            case .secret:
                secretThumbnail
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Achievement (always show icon)

    private var achievementThumbnail: some View {
        ZStack {
            Image(galleryImageName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .opacity(isUnlocked ? 1 : 0.38)
                .grayscale(isUnlocked ? 0 : 0.25)

            if !isUnlocked {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .stroke(DS.Color.coral.opacity(0.15), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DS.Color.coral, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size + 6, height: size + 6)
                    .rotationEffect(.degrees(-90))
                    .animation(DS.Animation.standard, value: progress)

                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.45), in: Circle())
            }

            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Color.black.opacity(isUnlocked ? 0.08 : 0.04), lineWidth: 1)
        }
    }

    // MARK: - Secret (question mark until unlocked)

    private var secretThumbnail: some View {
        Group {
            if isUnlocked {
                Image(galleryImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(DS.Color.tertiary.opacity(0.18))

                Text("?")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Color.tertiary)
            }
        }
    }
}
