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

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: containerWidth, height: containerHeight)
            .playerCoverArtClip()
            .frame(width: containerWidth, height: containerHeight)
            .applyShadows(DS.Shadow.coverArt)
    }
}
