//
//  SystemVolumeController.swift
//  Audiopig
//

import AVFoundation
import MediaPlayer
import UIKit

/// Sets system output volume via a hidden `MPVolumeView` slider.
@MainActor
final class SystemVolumeController {
    private let volumeView: MPVolumeView = {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        view.showsRouteButton = false
        view.isHidden = true
        view.alpha = 0.01
        return view
    }()

    init() {
        attachToKeyWindow()
    }

    var currentVolume: Float {
        AVAudioSession.sharedInstance().outputVolume
    }

    func setVolume(_ volume: Float) {
        attachToKeyWindow()
        let clamped = max(0, min(1, volume))
        if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
            slider.value = clamped
        }
    }

    private func attachToKeyWindow() {
        guard volumeView.superview == nil else { return }
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else { return }
        window.addSubview(volumeView)
    }
}
