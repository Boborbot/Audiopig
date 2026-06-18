//
//  AudiopigWidgetBundle.swift
//  AudiopigWidget
//

import WidgetKit
import SwiftUI

@main
struct AudiopigWidgetBundle: WidgetBundle {
    var body: some Widget {
        ListeningStatsWidget()
        ListeningArtworkWidget()
        ContinueListeningWidget()
        WeeklyListeningWidget()
        RecentBooksWidget()

        if #available(iOSApplicationExtension 18.0, *) {
            ContinueListeningControl()
        }
    }
}
