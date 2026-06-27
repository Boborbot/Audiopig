//
//  AppIconManagerTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

@MainActor
final class AppIconManagerTests: XCTestCase {

    private static let testDefaultsSuiteName = "com.nitay.AudiopigTests.AppIconManager"

    private func makeManager() -> AppIconManager {
        let defaults = UserDefaults(suiteName: Self.testDefaultsSuiteName)!
        defaults.removePersistentDomain(forName: Self.testDefaultsSuiteName)
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: "appicons.qa.unlockAll")
        #endif
        return AppIconManager(userDefaults: defaults)
    }

    func testHourTierUnlocksFromTotalListeningTime() {
        let manager = makeManager()

        let unlocks = manager.checkForNewUnlocks(totalListenedSeconds: 10 * 3_600)

        XCTAssertEqual(unlocks, [.achievement(.h10)])
        XCTAssertTrue(manager.isUnlocked(.h10))
        XCTAssertFalse(manager.isUnlocked(.h20))
    }

    func testHourTierDoesNotUnlockBelowThreshold() {
        let manager = makeManager()

        let unlocks = manager.checkForNewUnlocks(totalListenedSeconds: (10 * 3_600) - 1)

        XCTAssertTrue(unlocks.isEmpty)
        XCTAssertFalse(manager.isUnlocked(.h10))
    }

    func testSecretAchievementsStillRequireFinishEvent() {
        let manager = makeManager()
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 25
        components.hour = 12
        let christmas = Calendar.current.date(from: components)!

        _ = manager.checkForNewUnlocks(totalListenedSeconds: 100 * 3_600)

        let unlocks = manager.checkForNewUnlocks(
            totalListenedSeconds: 100 * 3_600,
            finishEvent: BookFinishEvent(
                audiobookID: UUID(),
                title: "A Book",
                author: "An Author",
                totalSeconds: 3_600,
                listenedSeconds: 3_600,
                chapterCount: 1,
                finishedAt: christmas,
                wasManuallyMarked: false
            )
        )

        XCTAssertEqual(unlocks, [.secret(.christmasDay)])
        XCTAssertTrue(manager.isUnlocked(.christmasDay))
    }
}
