//
//  AudiopigAppShortcuts.swift
//  Audiopig
//

import AppIntents

struct AudiopigAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayLastAudiobookIntent(),
            phrases: [
                "Continue listening in \(.applicationName)",
                "Resume audiobook in \(.applicationName)",
                "Play last book in \(.applicationName)",
            ],
            shortTitle: "Continue Listening",
            systemImageName: "play.fill"
        )
    }
}
