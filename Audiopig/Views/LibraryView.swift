//
//  LibraryView.swift
//  Audiopig
//

import SwiftUI
import UniformTypeIdentifiers

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
                            viewModel.reportError("Could not open the selected files. Please try again.")
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

                if viewModel.audiobooks.isEmpty && viewModel.folders.isEmpty && !viewModel.isImporting {
                    emptyState
                } else if viewModel.libraryItems.isEmpty && !viewModel.searchText.isEmpty {
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
            .overlay { importOverlay }
            .sheet(isPresented: $viewModel.isMergeSheetPresented) { mergeSheet }
            .sheet(isPresented: $viewModel.isFolderSheetPresented) { folderSheet }
            .sheet(item: $viewModel.bookPendingEdit) { audiobook in
                EditAudiobookView(audiobook: audiobook) {
                    viewModel.finishEdit()
                }
            }
            .navigationDestination(for: Folder.self) { folder in
                FolderContentView(folder: folder, viewModel: viewModel)
            }
        }
    }

    // MARK: - Book List

    private var bookList: some View {
        List {
            ForEach(viewModel.libraryItems) { item in
                switch item {
                case .audiobook(let audiobook):
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
                        editSwipeAction(for: audiobook)
                    }

                case .folder(let folder):
                    FolderListRow(folder: folder, viewModel: viewModel)
                        .disabled(viewModel.isSelectionModeActive)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // Attached to the List (never leaves the hierarchy) so the swipe-row
        // collapse animation cannot dismiss the dialog mid-presentation.
        .confirmationDialog(
            "Delete \"\(viewModel.folderPendingDelete?.title ?? "Folder")\"?",
            isPresented: Binding(
                get: { viewModel.folderPendingDelete != nil },
                set: { if !$0 { viewModel.folderPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Folder and All Books", role: .destructive) {
                if let folder = viewModel.folderPendingDelete {
                    viewModel.deleteFolderAndBooks(folder)
                }
                viewModel.folderPendingDelete = nil
            }
            Button("Delete Folder Only") {
                if let folder = viewModel.folderPendingDelete {
                    viewModel.deleteFolder(folder)
                }
                viewModel.folderPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                viewModel.folderPendingDelete = nil
            }
        } message: {
            Text("\"Delete Folder Only\" returns books to your library.")
        }
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

    @ViewBuilder
    private func editSwipeAction(for audiobook: Audiobook) -> some View {
        Button {
            viewModel.requestEdit(audiobook)
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.blue)
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
            if viewModel.isSelectionModeActive {
                Menu {
                    Button(role: .destructive) {
                        viewModel.requestBulkDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(!viewModel.canDeleteSelected)

                    Button {
                        viewModel.presentMergeSheet()
                    } label: {
                        Label("Combine into Volume", systemImage: "rectangle.stack.badge.plus")
                    }
                    .disabled(!viewModel.canMergeSelected)

                    Button {
                        viewModel.presentFolderSheet()
                    } label: {
                        Label("Combine into Folder", systemImage: "folder.badge.plus")
                    }
                    .disabled(!viewModel.canDeleteSelected)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .transition(.opacity)
            } else if !viewModel.isSearchActive {
                Button {
                    withAnimation(DS.Animation.standard) {
                        viewModel.isSearchActive = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .transition(.opacity)
                .accessibilityLabel("Search library")
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
                .accessibilityLabel("Add audiobook")
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

    // MARK: - Combine Sheet

    private var mergeSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Volume Title")
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
                    Text("Books to combine (\(viewModel.mergeOrder.count))")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    List {
                        ForEach(viewModel.mergeOrder) { book in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(Color(UIColor.systemGray3))
                                Text(book.title).font(.callout)
                                Spacer()
                            }
                            .padding(.vertical, DS.Spacing.xs)
                        }
                        .onMove { viewModel.moveMergeBook(from: $0, to: $1) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.input, style: .continuous)
                            .fill(DS.Color.secondarySurface)
                    )
                    .environment(\.editMode, .constant(.active))
                    .frame(minHeight: 44 * CGFloat(viewModel.mergeOrder.count))
                }

                Spacer()

                Button {
                    Task { await viewModel.mergeSelected() }
                } label: {
                    Group {
                        if viewModel.isMerging {
                            ProgressView().tint(.white)
                        } else {
                            Text("Combine into Volume")
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
            .navigationTitle("Combine into Volume")
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

    // MARK: - Folder Sheet

    private var folderSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Folder Name")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    TextField("Enter name…", text: $viewModel.pendingFolderTitle)
                        .font(.body)
                        .padding(DS.Spacing.sm + DS.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.input, style: .continuous)
                                .fill(DS.Color.secondarySurface)
                        )
                }

                Spacer()

                Button {
                    viewModel.createFolder()
                } label: {
                    Text("Create Folder")
                }
                .buttonStyle(DS.ButtonStyle.primary(
                    isDisabled: viewModel.pendingFolderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ))
                .disabled(
                    viewModel.pendingFolderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                .animation(DS.Animation.fade, value: viewModel.pendingFolderTitle.isEmpty)
            }
            .padding(DS.Spacing.md)
            .navigationTitle("Combine into Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.isFolderSheetPresented = false
                        viewModel.pendingFolderTitle = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - FolderListRow

private struct FolderListRow: View {
    let folder: Folder
    let viewModel: LibraryViewModel

    @State private var showEditSheet = false

    var body: some View {
        NavigationLink(value: folder) {
            FolderRowView(folder: folder)
        }
        .buttonStyle(.plain)
        .libraryCard()
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(
            top: DS.Spacing.xs,
            leading: 0,
            bottom: DS.Spacing.xs,
            trailing: 0
        ))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.folderPendingDelete = folder
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                showEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showEditSheet) {
            EditFolderView(folder: folder) {}
        }
    }
}
