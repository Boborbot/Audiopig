//
//  PigCelebrationView.swift
//  Audiopig
//
//  PigFaceView is kept here as a reusable mascot component.
//  Drop it into any future celebration, onboarding, or empty-state screen.
//

import SwiftUI

// MARK: - Pig Face

/// Audiopig mascot drawn entirely with SwiftUI shapes — no image assets required.
/// Uses brand coral (`DS.Color.coral`) and `DS.Color.pigSnout` for the snout.
struct PigFaceView: View {
    var body: some View {
        ZStack {
            ears
            head
            snout
            nostrils
            eyes
            arms
        }
        .frame(width: 100, height: 110)
    }

    private var head: some View {
        Circle()
            .fill(DS.Color.coral)
            .frame(width: 84, height: 84)
            .offset(y: 8)
    }

    private var ears: some View {
        HStack(spacing: 44) {
            Circle()
                .fill(DS.Color.coral)
                .frame(width: 28, height: 28)
            Circle()
                .fill(DS.Color.coral)
                .frame(width: 28, height: 28)
        }
        .offset(y: -28)
    }

    private var snout: some View {
        Ellipse()
            .fill(DS.Color.pigSnout)
            .frame(width: 40, height: 26)
            .offset(y: 26)
    }

    private var nostrils: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.black.opacity(0.35))
                .frame(width: 6, height: 6)
            Circle()
                .fill(.black.opacity(0.35))
                .frame(width: 6, height: 6)
        }
        .offset(y: 29)
    }

    private var eyes: some View {
        HStack(spacing: 22) {
            Circle()
                .fill(.black.opacity(0.70))
                .frame(width: 8, height: 8)
            Circle()
                .fill(.black.opacity(0.70))
                .frame(width: 8, height: 8)
        }
        .offset(y: 10)
    }

    /// Two short arms raised in celebration.
    private var arms: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DS.Color.coral)
                .frame(width: 10, height: 28)
                .rotationEffect(.degrees(-40))
                .offset(x: -56, y: 28)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DS.Color.coral)
                .frame(width: 10, height: 28)
                .rotationEffect(.degrees(40))
                .offset(x: 56, y: 28)
        }
    }
}
