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
        WeeklyListeningWidget()
        RecentBooksWidget()
    }
}
