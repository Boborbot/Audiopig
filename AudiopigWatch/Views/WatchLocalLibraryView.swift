//
//  WatchLocalLibraryView.swift
//  AudiopigWatch
//

import SwiftUI

struct WatchLocalLibraryView: View {
    @ObservedObject var libraryViewModel: WatchLocalLibraryViewModel
    @ObservedObject var playerViewModel: WatchPlayerViewModel
    var onBookSelected: () -> Void
    var onBack: (() -> Void)?

    @State private var showImportInstructions = false

    init(
        libraryViewModel: WatchLocalLibraryViewModel,
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
        .navigationTitle("Watch")
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    NavigationLink {
                        WatchSettingsView(playerViewModel: playerViewModel)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    Button {
                        showImportInstructions = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showImportInstructions) {
            NavigationStack {
                WatchImportInstructionsView()
            }
        }
        .onAppear {
            libraryViewModel.onAppear()
        }
    }

    private var bookList: some View {
        List {
            Section {
                Text(libraryViewModel.storageLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

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
            if let error = libraryViewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.bottom, WDS.Spacing.xs)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: WDS.Spacing.md) {
            Image(systemName: "applewatch")
                .font(.title2)
                .foregroundStyle(WDS.Color.coral)
            Text("No books on Watch")
                .font(.caption)

            Button("Add from iPhone") {
                showImportInstructions = true
            }
            .buttonStyle(.borderedProminent)
            .tint(WDS.Color.coral)
        }
        .padding()
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
