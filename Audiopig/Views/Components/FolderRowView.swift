//
//  FolderRowView.swift
//  Audiopig
//

import SwiftUI

struct FolderRowView: View {
    let folder: Folder

    var body: some View {
        HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
            coverArtwork
                .frame(width: 60, height: 60)
                .listCoverArtClip()
            folderInfo
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
    }

    // MARK: - Cover Artwork

    @ViewBuilder
    private var coverArtwork: some View {
        let books = folder.sortedAudiobooks
        if books.count >= 4 {
            fourGrid(Array(books.prefix(4)))
        } else if let first = books.first {
            singleCover(first)
        } else {
            defaultIcon
        }
    }

    private var defaultIcon: some View {
        ZStack {
            DS.Color.coral.opacity(0.15)
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(DS.Color.coral)
        }
    }

    @ViewBuilder
    private func singleCover(_ book: Audiobook) -> some View {
        if let img = CoverArtCache.shared.image(for: book) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                book.placeholderColor.opacity(0.75)
                Image(systemName: "headphones")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func fourGrid(_ books: [Audiobook]) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 1) {
                gridCell(books[0])
                gridCell(books[1])
            }
            HStack(spacing: 1) {
                gridCell(books[2])
                gridCell(books[3])
            }
        }
    }

    @ViewBuilder
    private func gridCell(_ book: Audiobook) -> some View {
        if let img = CoverArtCache.shared.image(for: book) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 29.5, height: 29.5)
                .clipped()
        } else {
            book.placeholderColor.opacity(0.75)
                .frame(width: 29.5, height: 29.5)
        }
    }

    // MARK: - Info

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
