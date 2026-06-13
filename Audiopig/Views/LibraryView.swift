//
//  LibraryView.swift
//  Audiopig
//

import SwiftUI
import UniformTypeIdentifiers
import AudioToolbox

struct LibraryView: View {
    @State private var viewModel: LibraryViewModel
    @FocusState private var isSearchFocused: Bool

    /// Drives the single shared .fileImporter modifier.
    @State private var isImporterPresented: Bool = false
    /// When true the importer shows folders; when false it shows audio files.
    @State private var isImportingFolder: Bool = false

    private static let allowedAudioTypes: [UTType] = {
        var types: [UTType] = [.mp3, .mpeg4Audio]
        if let m4b = UTType(filenameExtension: "m4b") { types.append(m4b) }
        return types
    }()

    init(viewModel: LibraryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private func presentFileImporter() {
        isImportingFolder = false
        isImporterPresented = true
    }

    private func presentFolderImporter() {
        isImportingFolder = true
        isImporterPresented = true
    }

    var body: some View {
        navigationContent
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: isImportingFolder ? [.folder] : Self.allowedAudioTypes,
                allowsMultipleSelection: !isImportingFolder
            ) { result in
                if isImportingFolder {
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            Task { await viewModel.importFolder(url) }
                        }
                    case .failure(let error):
                        if (error as NSError).code != NSUserCancelledError {
                            viewModel.reportError("Could not open the selected folder.")
                        }
                    }
                } else {
                    switch result {
                    case .success(let urls):
                        Task { await viewModel.importFiles(urls) }
                    case .failure(let error):
                        if (error as NSError).code != NSUserCancelledError {
                            Task { await viewModel.importFiles([]) }
                        }
                    }
                }
            }
            .alert("Delete Audiobook?", isPresented: $viewModel.isSwipeDeleteConfirmationPresented) {
                Button("Delete", role: .destructive) { viewModel.confirmSwipeDelete() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove the audiobook and its file.")
            }
            .alert(
                "Delete \(viewModel.selectedCount) \(viewModel.selectedCount == 1 ? "Book" : "Books")?",
                isPresented: $viewModel.isBulkDeleteConfirmationPresented
            ) {
                Button("Delete", role: .destructive) { viewModel.confirmBulkDelete() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove the selected audiobooks and their files.")
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.clearError() } }
                )
            ) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    // MARK: - Navigation Content

    private var navigationContent: some View {
        NavigationStack {
            ZStack {
                DS.Color.canvas.ignoresSafeArea()

                if viewModel.audiobooks.isEmpty && !viewModel.isImporting {
                    emptyState
                } else if viewModel.filteredAudiobooks.isEmpty && !viewModel.searchText.isEmpty {
                    noSearchResultsState
                } else {
                    bookList
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .coralNavigationBanner()
            .toolbar { toolbarItems }
            .safeAreaInset(edge: .top, spacing: 0) { searchBarHeader }
            .onChange(of: viewModel.isSearchActive) { _, active in
                if active {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isSearchFocused = true
                    }
                } else {
                    isSearchFocused = false
                }
            }
            .safeAreaInset(edge: .bottom) { mergeBar }
            .overlay { importOverlay }
            .overlay { celebrationOverlay }
            .onChange(of: viewModel.celebratedBook?.id) { _, bookID in
                guard bookID != nil else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                // System sound 1073 ("mail sent" ascending chime) — plays over existing
                // audio via its own ambient session; silently ignored if unavailable.
                AudioServicesPlaySystemSound(SystemSoundID(1073))
            }
            .sheet(isPresented: $viewModel.isMergeSheetPresented) { mergeSheet }
        }
    }

    // MARK: - Celebration Overlay

    @ViewBuilder
    private var celebrationOverlay: some View {
        if viewModel.celebratedBook != nil {
            ConfettiBurstView {
                viewModel.dismissCelebration()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: - Book List

    private var bookList: some View {
        List {
            ForEach(viewModel.filteredAudiobooks) { audiobook in
                AudiobookRowView(
                    audiobook: audiobook,
                    isSelectionModeActive: viewModel.isSelectionModeActive,
                    isSelected: viewModel.isSelected(audiobook),
                    onTap: { viewModel.openPlayer(for: audiobook) },
                    onToggleSelection: { viewModel.toggleSelection(audiobook) }
                )
                .libraryCard()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: DS.Spacing.xs,
                    leading: 0,
                    bottom: DS.Spacing.xs,
                    trailing: 0
                ))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    finishSwipeAction(for: audiobook)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    deleteSwipeAction(for: audiobook)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Swipe Actions

    @ViewBuilder
    private func finishSwipeAction(for audiobook: Audiobook) -> some View {
        if audiobook.isFinished {
            Button {
                viewModel.markUnfinished(audiobook)
            } label: {
                Label("Unfinish", systemImage: "arrow.counterclockwise")
            }
            .tint(DS.Color.coral.opacity(0.6))
        } else {
            Button {
                viewModel.markFinished(audiobook)
            } label: {
                Label("Finished", systemImage: "checkmark.circle.fill")
            }
            .tint(DS.Color.coral)
        }
    }

    @ViewBuilder
    private func deleteSwipeAction(for audiobook: Audiobook) -> some View {
        Button(role: .destructive) {
            viewModel.requestDelete(audiobook)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Search Bar

    @ViewBuilder
    private var searchBarHeader: some View {
        if viewModel.isSearchActive {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Color.secondary)
                    .font(.body)

                TextField("Title, author, or file name", text: $viewModel.searchText)
                    .focused($isSearchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.body)
                    .submitLabel(.search)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DS.Color.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Button("Cancel") {
                    withAnimation(DS.Animation.standard) {
                        viewModel.clearSearch()
                    }
                }
                .foregroundStyle(DS.Color.coral)
                .font(.callout.weight(.medium))
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
            .background {
                Capsule()
                    .fill(DS.Color.secondarySurface)
                    .applyShadows(DS.Shadow.card)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .transition(
                .scale(scale: 0.01, anchor: UnitPoint(x: 0.05, y: 0.5))
                .combined(with: .opacity)
            )
        }
    }

    // MARK: - No Search Results

    private var noSearchResultsState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color(UIColor.systemGray3))

            Text("No Results")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DS.Color.primary)

            Text("No audiobooks match \"\(viewModel.searchText)\".")
                .font(.subheadline)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.xl)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "headphones")
                .font(.system(size: 52))
                .foregroundStyle(Color(UIColor.systemGray3))

            Text("Your Library is Empty")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DS.Color.primary)

            Text("Tap + to add M4B or MP3 audiobooks.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)

            Button {
                presentFileImporter()
            } label: {
                Label("Add Audiobooks", systemImage: "plus")
            }
            .buttonStyle(DS.ButtonStyle.primary())
            .frame(maxWidth: 220)
            .padding(.top, DS.Spacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.xl)
    }

    // MARK: - Import Overlay

    @ViewBuilder
    private var importOverlay: some View {
        if viewModel.isImporting {
            ZStack {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()

                VStack(spacing: DS.Spacing.md) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.4)
                    Text("Importing…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg + DS.Spacing.sm)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: DS.Radius.sheet, style: .continuous)
                )
            }
            .transition(.opacity)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if viewModel.isSelectionModeActive && viewModel.canDeleteSelected {
                Button(role: .destructive) {
                    viewModel.requestBulkDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .transition(.opacity)
            } else if !viewModel.isSelectionModeActive && !viewModel.isSearchActive {
                Button {
                    withAnimation(DS.Animation.standard) {
                        viewModel.isSearchActive = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .transition(.opacity)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if !viewModel.isSelectionModeActive {
                Menu {
                    Button {
                        presentFileImporter()
                    } label: {
                        Label("Add Files", systemImage: "doc.badge.plus")
                    }
                    Button {
                        presentFolderImporter()
                    } label: {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .transition(.opacity)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if !viewModel.audiobooks.isEmpty {
                Button(viewModel.isSelectionModeActive ? "Done" : "Select") {
                    withAnimation(DS.Animation.standard) {
                        viewModel.toggleSelectionMode()
                    }
                }
                .fontWeight(.medium)
                .animation(nil, value: viewModel.isSelectionModeActive)
            }
        }
    }

    // MARK: - Floating Merge Bar

    @ViewBuilder
    private var mergeBar: some View {
        if viewModel.isSelectionModeActive && viewModel.canMergeSelected {
            Button {
                viewModel.isMergeSheetPresented = true
            } label: {
                Label(
                    "Merge \(viewModel.selectedCount) Books",
                    systemImage: "rectangle.stack.badge.plus"
                )
            }
            .buttonStyle(DS.ButtonStyle.primary())
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Merge Sheet

    private var mergeSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("New Audiobook Title")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    TextField("Enter title…", text: $viewModel.pendingMergeTitle)
                        .font(.body)
                        .padding(DS.Spacing.sm + DS.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.input, style: .continuous)
                                .fill(DS.Color.secondarySurface)
                        )
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Books to merge (\(viewModel.selectedCount))")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    let selectedBooks = viewModel.audiobooks.filter { viewModel.isSelected($0) }
                    VStack(spacing: 0) {
                        ForEach(selectedBooks) { book in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(Color(UIColor.systemGray3))
                                Text(book.title).font(.callout)
                                Spacer()
                            }
                            .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
                            .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xs)
                            if book.id != selectedBooks.last?.id {
                                Divider().padding(.leading, DS.Spacing.sm + DS.Spacing.xs)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.input, style: .continuous)
                            .fill(DS.Color.secondarySurface)
                    )
                }

                Spacer()

                Button {
                    Task { await viewModel.mergeSelected() }
                } label: {
                    Group {
                        if viewModel.isMerging {
                            ProgressView().tint(.white)
                        } else {
                            Text("Merge into One Book")
                        }
                    }
                }
                .buttonStyle(DS.ButtonStyle.primary(
                    isDisabled: viewModel.pendingMergeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ))
                .disabled(
                    viewModel.pendingMergeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isMerging
                )
                .animation(DS.Animation.fade, value: viewModel.pendingMergeTitle.isEmpty)
            }
            .padding(DS.Spacing.md)
            .navigationTitle("Merge Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.isMergeSheetPresented = false
                        viewModel.pendingMergeTitle = ""
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
