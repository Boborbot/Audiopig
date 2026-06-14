//
//  FolderRowView.swift
//  Audiopig
//

import SwiftUI

struct FolderRowView: View {
    let folder: Folder

    var body: some View {
        HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
            folderIcon
            folderInfo
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Color.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
    }

    private var folderIcon: some View {
        ZStack {
            DS.Color.coral.opacity(0.15)
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(DS.Color.coral)
        }
        .frame(width: 60, height: 60)
        .listCoverArtClip()
    }

    private var folderInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(folder.title)
                .font(DS.Typography.listTitle)
                .foregroundStyle(DS.Color.primary)
                .lineLimit(1)

            Text("\(folder.bookCount) \(folder.bookCount == 1 ? "book" : "books")")
                .font(.subheadline)
                .foregroundStyle(DS.Color.secondary)
                .lineLimit(1)
        }
    }
}
