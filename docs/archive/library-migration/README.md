# Archived: Library Migration (Import Folder + Backup/Restore)

**Status:** Archived — not shipped, not compiled into the app.  
**Archived:** 2026-06-21  
**Reason:** Product decision to defer bulk migration and backup/restore UX until fingerprint matching and performance are hardened.

## What this was

A two-phase, App Store–safe library migration experiment:

| Phase | Capability |
|-------|------------|
| **Phase 1** | Import an entire folder from Files (e.g. BookPlayer `Processed`), with MP3 volume grouping, duplicate skip, import summary |
| **Phase 2** | Export `AudiopigLibraryBackup.v1.json` (progress, bookmarks, folders) and restore via fingerprint match (filename + size + duration) |

It deliberately did **not** read other apps' sandboxes or parse BookPlayer's database.

## Why it was removed from the app

- Multiple stacked `.fileImporter` modifiers broke single-file import in the Library UI.
- Fingerprint matching is brittle across re-import (renamed copies like `book-1.m4b`).
- Large-folder import was main-thread sequential with no progress/cancellation.
- UX surface (menu, guide sheet, Settings backup section) was broader than needed for v1.

Core single-file import (`LibraryViewModel.importFiles` + `LibraryManager.importAndPersist`) remains the supported path.

## File inventory

```
ViewModels/LibraryImportViewModel.swift
Views/Components/ImportLibrarySheet.swift
Services/LibraryImportService.swift
Services/LibraryBackupService.swift
Protocols/LibraryImportServiceProtocol.swift
Protocols/LibraryBackupServiceProtocol.swift
AudiopigShared/FolderImportGrouping.swift
AudiopigShared/AudiobookFingerprint.swift
AudiopigShared/LibraryBackupManifest.swift
Tests/FolderImportGroupingTests.swift
Tests/LibraryBackupManifestTests.swift
Tests/LibraryBackupServiceTests.swift
snippets-LibraryManager-importVolume.swift   # importVolume() removed from LibraryManager
```

## How to restore (developer)

1. Copy `AudiopigShared/*` back into `Audiopig/AudiopigShared/` and add to the shared target.
2. Copy Services, Protocols, ViewModels, Views back into `Audiopig/Audiopig/`.
3. Re-add `importVolume(from:suggestedTitle:)` to `LibraryManager` and `LibraryManagerProtocol` (see `snippets-LibraryManager-importVolume.swift`).
4. Wire `LibraryImportService` and `LibraryBackupService` in `DependencyContainer` and `AudiopigApp`.
5. Pass both services into `LibraryViewModel` init; restore `importViewModel` property.
6. Re-add UI in `LibraryView`, `ImportLibrarySheet`, and optionally `SettingsView`.
7. Copy Tests back into `AudiopigTests/`.
8. **Use only one primary `.fileImporter` for audio**, or use `UIDocumentPickerViewController` for secondary flows — multiple SwiftUI `fileImporter` bindings on one view caused the file-import regression.

## Known gaps (if revived)

- Multi-file volume duplicate detection omitted file size.
- Mixed M4B + MP3 in one folder merges into one broken volume.
- Backup export silently skipped books with unreadable files.
- Duplicate folder titles on restore could trap (`Dictionary(uniqueKeysWithValues:)`).
- Matcher `stableID` vs fuzzy `matches()` could disagree at margins.

## Related plans (Cursor)

- `library_import_migration_ae2594bd.plan.md`
- `import_phased_execution_2854aa14.plan.md`
