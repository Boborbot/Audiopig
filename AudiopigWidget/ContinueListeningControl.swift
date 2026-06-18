//
//  ContinueListeningControl.swift
//  AudiopigWidget
//
//  iOS 18+ control for the Lock Screen bottom corners (flashlight / camera slots)
//  and Control Center. Tap to resume the last audiobook without opening the app.
//

import AppIntents
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 18.0, *)
struct ContinueListeningControl: ControlWidget {
    let kind = WidgetListeningSnapshot.continueListeningControlKind

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: PlayLastAudiobookIntent()) {
                Label("Continue Listening", systemImage: "play.fill")
            }
        }
        .displayName("Continue Listening")
        .description("Resume your last audiobook.")
    }
}
