//
//  SecretAchievement.swift
//  Audiopig
//
//  Hidden achievements that unlock special app icons when their conditions are met.
//
//  Adding a new achievement:
//  1. Add a case below with icon metadata.
//  2. Implement its condition in `isUnlocked(by:calendar:)`.
//  3. Add `AppIcon-<name>.appiconset` to Assets.xcassets.
//  4. Register the icon name in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
//

import Foundation

enum SecretAchievement: String, CaseIterable, Identifiable {
    case christmasDay
    case newYearsEve

    var id: String { rawValue }

    /// Asset catalog alternate icon name (matches appiconset folder name).
    var iconName: String {
        switch self {
        case .christmasDay: return "AppIcon-ChristmasDay"
        case .newYearsEve:  return "AppIcon-NewYearsEve"
        }
    }

    /// Gallery thumbnail in Assets.xcassets (matches imageset folder name).
    var galleryImageName: String {
        switch self {
        case .christmasDay: return "Gallery-ChristmasDay"
        case .newYearsEve:  return "Gallery-NewYearsEve"
        }
    }

    /// Revealed only after unlock.
    var label: String {
        switch self {
        case .christmasDay: return "Christmas Day"
        case .newYearsEve:  return "New Year's Ten Hours"
        }
    }

    var unlockDescription: String {
        switch self {
        case .christmasDay:
            return "The best gift is a finished book."
        case .newYearsEve:
            return "What year is it?"
        }
    }

    // MARK: - Evaluation

    func isUnlocked(by event: BookFinishEvent, calendar: Calendar = .current) -> Bool {
        switch self {
        case .christmasDay:
            return ChristmasDayFinishCondition.isSatisfied(by: event, calendar: calendar)
        case .newYearsEve:
            return NewYearsEveFinishCondition.isSatisfied(by: event, calendar: calendar)
        }
    }
}

// MARK: - Conditions

/// Finish a book on December 25 (local time).
enum ChristmasDayFinishCondition {
    static func isSatisfied(by event: BookFinishEvent, calendar: Calendar = .current) -> Bool {
        isChristmasDay(event.finishedAt, calendar: calendar)
    }

    static func isChristmasDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return parts.month == 12 && parts.day == 25
    }
}

/// Finish a book between 20:00 on Dec 31 and 06:00 on Jan 1 (local time) — a ten-hour window.
enum NewYearsEveFinishCondition {
    static func isSatisfied(by event: BookFinishEvent, calendar: Calendar = .current) -> Bool {
        isWithinWindow(event.finishedAt, calendar: calendar)
    }

    static func isWithinWindow(_ date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.month, .day, .hour], from: date)
        guard let month = parts.month, let day = parts.day, let hour = parts.hour else {
            return false
        }

        if month == 12, day == 31, hour >= 20 { return true }
        if month == 1, day == 1, hour < 6 { return true }
        return false
    }
}
