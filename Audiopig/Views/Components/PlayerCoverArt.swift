//
//  PlayerCoverArt.swift
//  Audiopig
//
//  Fixed-height hero cover art for PlayerView.
//  Portrait art is height-fitted and centered; wide art fills the slot horizontally.
//  Side gutters stay transparent so the ambient player background shows through.
//

import SwiftUI

struct PlayerCoverArt: View {
    let image: UIImage
    let containerWidth: CGFloat
    let containerHeight: CGFloat

    private var imageAspectRatio: CGFloat {
        let size = image.size
        guard size.height > 0 else { return 1 }
        return size.width / size.height
    }

    var body: some View {
        ZStack {
            if imageAspectRatio > 1 {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: containerWidth, height: containerHeight)
                    .playerCoverArtClip()
            } else {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: containerHeight)
                    .playerCoverArtClip()
            }
        }
        .frame(width: containerWidth, height: containerHeight)
        .applyShadows(DS.Shadow.coverArt)
    }
}
