//
//  SettingsView.swift
//  Audiopig
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    @State private var isDeleteStatsConfirmationPresented = false
    @State private var isShareAllExportedPresented = false
    @State private var shareAllExportedItems: [Any] = []
    @State private var exportedNoteCount = 0

    private static let skipIntervalOptions: [TimeInterval] = [5, 10, 15, 30, 45, 60]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                        .sectionTitle()
                }

                Section {
                    Picker("Default Speed", selection: $settings.defaultSpeed) {
                        ForEach(PlayerViewModel.availableSpeeds, id: \.self) { speed in
                            Text(speedLabel(speed)).tag(speed)
                        }
                    }
                    .tint(DS.Color.coral)

                    Picker("Skip Forward", selection: $settings.skipForwardInterval) {
                        ForEach(Self.skipIntervalOptions, id: \.self) { seconds in
                            Text("\(Int(seconds))s").tag(seconds)
                        }
                    }
                    .tint(DS.Color.coral)

                    Picker("Skip Backward", selection: $settings.skipBackwardInterval) {
                        ForEach(Self.skipIntervalOptions, id: \.self) { seconds in
                            Text("\(Int(seconds))s").tag(seconds)
                        }
                    }
                    .tint(DS.Color.coral)
                } header: {
                    Text("Playback")
                        .sectionTitle()
                }

                Section {
                    Toggle(isOn: $settings.autoDeleteOnFinish) {
                        Label("Delete book when finished", systemImage: "checkmark.circle")
                    }
                    .tint(DS.Color.coral)

                    Toggle(isOn: $settings.trackReadingStats) {
                        Label("Track reading stats", systemImage: "chart.bar")
                    }
                    .tint(DS.Color.coral)

                    if settings.trackReadingStats {
                        Button(role: .destructive) {
                            isDeleteStatsConfirmationPresented = true
                        } label: {
                            Label("Delete all reading data", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Library")
                        .sectionTitle()
                } footer: {
                    Text("Reading data is stored only on this device and is never shared.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.tertiary)
                }

                Section {
                    Toggle(isOn: $settings.autoExportOnFinish) {
                        Label("Auto-export on book completion", systemImage: "bookmark")
                    }
                    .tint(DS.Color.coral)

                    Toggle(isOn: $settings.autoExportOnDelete) {
                        Label("Auto-export on book removal", systemImage: "bookmark")
                    }
                    .tint(DS.Color.coral)

                    Button {
                        shareAllExportedNotes()
                    } label: {
                        Label("Share All Exported Notes", systemImage: "square.and.arrow.up")
                    }
                    .disabled(exportedNoteCount == 0)
                } header: {
                    Text("Bookmark Export")
                        .sectionTitle()
                } footer: {
                    Text("Notes are saved to On My iPhone › Audiopig › Exported Bookmarks and are visible in the Files app.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.tertiary)
                }

                Section {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                    Label("Version \(version) (\(build))", systemImage: "info.circle")
                        .foregroundStyle(DS.Color.secondary)
                } header: {
                    Text("About")
                        .sectionTitle()
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.Color.canvas.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .coralNavigationBanner()
            .alert("Delete all reading data?", isPresented: $isDeleteStatsConfirmationPresented) {
                Button("Delete", role: .destructive) { deleteAllStats() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your entire reading history will be permanently removed. This cannot be undone.")
            }
            .sheet(isPresented: $isShareAllExportedPresented) {
                ShareActivityView(activityItems: shareAllExportedItems)
            }
            .onAppear { refreshExportedNoteCount() }
        }
    }

    // MARK: - Bookmark export

    private func refreshExportedNoteCount() {
        exportedNoteCount = BookmarkExportService.allExportedFiles().count
    }

    private func shareAllExportedNotes() {
        let files = BookmarkExportService.allExportedFiles()
        guard !files.isEmpty else { return }
        shareAllExportedItems = files
        isShareAllExportedPresented = true
    }

    // MARK: - Stats management

    private func deleteAllStats() {
        let records = (try? modelContext.fetch(FetchDescriptor<FinishedRecord>())) ?? []
        records.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }

    private func speedLabel(_ speed: Float) -> String {
        speed.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(speed))×"
            : String(format: "%.2g×", speed)
    }
}
