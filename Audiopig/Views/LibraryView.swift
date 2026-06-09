//
//  LibraryView.swift
//  Audiopig
//

import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @State private var viewModel: LibraryViewModel

    // Allowed audio file types for the file importer.
    private static let allowedTypes: [UTType] = {
        var types: [UTType] = [.mp3, .mpeg4Audio]
        if let m4b = UTType(filenameExtension: "m4b") { types.append(m4b) }
        return types
    }()

    init(viewModel: LibraryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.audiobooks.isEmpty && !viewModel.isImporting {
                    emptyState
                } else {
                    bookList
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarItems }
            .safeAreaInset(edge: .bottom) { mergeBar }
            // Import loading overlay
            .overlay { importOverlay }
            // Merge title sheet
            .sheet(isPresented: $viewModel.isMergeSheetPresented) { mergeSheet }
            // File importer
            .fileImporter(
                isPresented: $viewModel.isFileImporterPresented,
                allowedContentTypes: Self.allowedTypes,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task { await viewModel.importFiles(urls) }
                case .failure(let error):
                    // Only surface user-facing errors (cancelled = no-op).
                    if (error as NSError).code != NSUserCancelledError {
                        Task { await viewModel.importFiles([]) }  // triggers no-op; error shown inline
                    }
                }
            }
            // Error alert
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
    }

    // MARK: - Book List

    private var bookList: some View {
        List {
            ForEach(viewModel.audiobooks) { audiobook in
                AudiobookRowView(
                    audiobook: audiobook,
                    isSelectionModeActive: viewModel.isSelectionModeActive,
                    isSelected: viewModel.isSelected(audiobook),
                    onTap: { viewModel.openPlayer(for: audiobook) },
                    onToggleSelection: { viewModel.toggleSelection(audiobook) }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            }
            .onDelete { indexSet in
                viewModel.delete(at: indexSet)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "headphones")
                .font(.system(size: 52))
                .foregroundStyle(Color(.systemGray3))

            Text("Your Library is Empty")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Tap + to add M4B or MP3 audiobooks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.isFileImporterPresented = true
            } label: {
                Label("Add Audiobooks", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Import Overlay

    @ViewBuilder
    private var importOverlay: some View {
        if viewModel.isImporting {
            ZStack {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.4)
                    Text("Importing…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .transition(.opacity)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // "+" — only when not in selection mode
        ToolbarItem(placement: .navigationBarTrailing) {
            if !viewModel.isSelectionModeActive {
                Button {
                    viewModel.isFileImporterPresented = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .transition(.opacity)
            }
        }

        // Select / Done
        ToolbarItem(placement: .navigationBarTrailing) {
            if !viewModel.audiobooks.isEmpty {
                Button(viewModel.isSelectionModeActive ? "Done" : "Select") {
                    withAnimation(.easeInOut(duration: 0.22)) {
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
                .font(.system(.body, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .buttonStyle(.plain)
            .shadow(color: Color.accentColor.opacity(0.35), radius: 12, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Merge Sheet

    private var mergeSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("New Audiobook Title")
                        .font(.caption).foregroundStyle(.secondary)
                        .textCase(.uppercase).tracking(0.5)

                    TextField("Enter title…", text: $viewModel.pendingMergeTitle)
                        .font(.body)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Books to merge (\(viewModel.selectedCount))")
                        .font(.caption).foregroundStyle(.secondary)
                        .textCase(.uppercase).tracking(0.5)

                    let selectedBooks = viewModel.audiobooks.filter { viewModel.isSelected($0) }
                    VStack(spacing: 0) {
                        ForEach(selectedBooks) { book in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(Color(.systemGray3))
                                Text(book.title).font(.callout)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            if book.id != selectedBooks.last?.id {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
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
                                .font(.system(.body, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        viewModel.pendingMergeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(.systemGray4)
                            : Color.accentColor,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(
                    viewModel.pendingMergeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isMerging
                )
                .animation(.easeInOut(duration: 0.15), value: viewModel.pendingMergeTitle.isEmpty)
            }
            .padding(20)
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
