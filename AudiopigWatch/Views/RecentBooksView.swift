//
//  RecentBooksView.swift
//  AudiopigWatch
//

import SwiftUI

struct RecentBooksView: View {
    @ObservedObject var libraryViewModel: WatchLibraryViewModel
    @ObservedObject var playerViewModel: WatchPlayerViewModel
    var onBookSelected: () -> Void
    var onBack: (() -> Void)?

    init(
        libraryViewModel: WatchLibraryViewModel,
        playerViewModel: WatchPlayerViewModel,
        onBookSelected: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        _libraryViewModel = ObservedObject(wrappedValue: libraryViewModel)
        _playerViewModel = ObservedObject(wrappedValue: playerViewModel)
        self.onBookSelected = onBookSelected
        self.onBack = onBack
    }

    var body: some View {
        Group {
            if libraryViewModel.books.isEmpty {
                emptyState
            } else {
                bookList
            }
        }
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    WatchSettingsView(playerViewModel: playerViewModel)
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .task {
            await libraryViewModel.onAppear()
        }
    }

    private var bookList: some View {
        List {
            ForEach(libraryViewModel.books) { book in
                Button {
                    onBookSelected()
                    Task {
                        _ = await libraryViewModel.selectBook(id: book.id)
                    }
                } label: {
                    HStack(spacing: WDS.Spacing.sm) {
                        thumbnail(for: book)
                        Text(book.title)
                            .font(WDS.Typography.title)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
                .disabled(libraryViewModel.isLoading)
            }
        }
        .overlay(alignment: .bottom) {
            statusFooter
        }
    }

    private var emptyState: some View {
        VStack(spacing: WDS.Spacing.md) {
            if libraryViewModel.isLoading {
                ProgressView()
            } else {
                Image(systemName: "books.vertical")
                    .font(.title2)
                    .foregroundStyle(WDS.Color.coral)
                Text("No recent books")
                    .font(.caption)
                Text("Play on iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let message = libraryViewModel.connectionStatusMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let error = libraryViewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Refresh") {
                Task { await libraryViewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(WDS.Color.coral)
        }
        .padding()
    }

    @ViewBuilder
    private var statusFooter: some View {
        if let error = libraryViewModel.errorMessage, !libraryViewModel.books.isEmpty {
            Text(error)
                .font(.caption2)
                .foregroundStyle(.red)
                .padding(.bottom, WDS.Spacing.xs)
        }
    }

    @ViewBuilder
    private func thumbnail(for book: WatchBookSummary) -> some View {
        Group {
            if let image = book.thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(WDS.Color.placeholder)
                    .overlay {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
