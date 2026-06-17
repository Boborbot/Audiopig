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
                ForEach(viewModel.audiobooks) { audiobook in
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
                                        .foregroundStyle(DS.Color.secondary)
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
                Text("Keep devices nearby during transfer.")
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
        .onAppear { viewModel.refresh() }
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
        case .transferring:
            ProgressView()
                .controlSize(.small)
        case .unavailable:
            EmptyView()
        }
    }

    private func statusLabel(for audiobook: Audiobook) -> String {
        switch viewModel.status(for: audiobook) {
        case .onWatch: return "On Watch"
        case .transferring: return "Transferring…"
        case .notOnWatch: return "Not on Watch"
        case .unavailable: return "Watch unavailable"
        }
    }
}
