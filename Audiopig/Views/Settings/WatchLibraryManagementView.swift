//
//  WatchLibraryManagementView.swift
//  Audiopig
//

import SwiftUI

struct WatchLibraryManagementView: View {
    @State private var viewModel: WatchLibraryManagementViewModel

    init(libraryViewModel: LibraryViewModel) {
        _viewModel = State(initialValue: WatchLibraryManagementViewModel(libraryViewModel: libraryViewModel))
    }

    var body: some View {
        let _ = viewModel.transferStateRevision

        List {
            Section {
                Text(viewModel.storageLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.secondary)
            } header: {
                Text("Watch Storage")
                    .sectionTitle()
            }

            Section {
                ForEach(viewModel.audiobooks, id: \.id) { audiobook in
                    HStack {
                        Button {
                            viewModel.toggleSelection(audiobook)
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: viewModel.isSelected(audiobook) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.isSelected(audiobook) ? DS.Color.coral : DS.Color.tertiary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(audiobook.title)
                                        .font(DS.Typography.listTitle)
                                        .foregroundStyle(DS.Color.primary)
                                    Text(statusLabel(for: audiobook))
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(statusColor(for: audiobook))
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        watchAction(for: audiobook)
                    }
                }
            } header: {
                Text("Library")
                    .sectionTitle()
            } footer: {
                Text("Large audiobooks can take several minutes. Open \(Brand.displayName) on your Watch before transferring.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.tertiary)
            }
        }
        .navigationTitle("Watch Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Transfer") {
                    Task { await viewModel.transferSelected() }
                }
                .disabled(viewModel.selectedIDs.isEmpty)
            }
        }
        .onAppear {
            viewModel.refresh()
            Task { await viewModel.syncWatchLibrary() }
        }
        .task {
            while !Task.isCancelled {
                if viewModel.hasActiveTransfers {
                    await viewModel.syncWatchLibrary()
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    @ViewBuilder
    private func watchAction(for audiobook: Audiobook) -> some View {
        switch viewModel.status(for: audiobook) {
        case .onWatch:
            Button("Remove") {
                Task { await viewModel.removeFromWatch(audiobook) }
            }
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Color.coral)
        case .notOnWatch:
            Button("Send") {
                Task { await viewModel.transfer(audiobook) }
            }
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Color.coral)
        case .transferring(let progress):
            HStack(spacing: DS.Spacing.sm) {
                ProgressView(value: progress.overallFraction)
                    .controlSize(.small)
                    .frame(width: 28)
                Button("Cancel") {
                    viewModel.cancelTransfer(audiobook)
                }
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.secondary)
            }
        case .failed:
            Button("Retry") {
                Task { await viewModel.transfer(audiobook) }
            }
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Color.coral)
        case .unavailable:
            EmptyView()
        }
    }

    private func statusLabel(for audiobook: Audiobook) -> String {
        switch viewModel.status(for: audiobook) {
        case .onWatch:
            return "On Watch"
        case .transferring(let progress):
            return "\(progress.displayLabel) \(progress.overallPercent)%"
        case .notOnWatch:
            return "Not on Watch"
        case .failed(let message):
            return message
        case .unavailable:
            return "Watch unavailable"
        }
    }

    private func statusColor(for audiobook: Audiobook) -> Color {
        if case .failed = viewModel.status(for: audiobook) {
            return DS.Color.coral
        }
        return DS.Color.secondary
    }
}
