//
//  FinishCelebrationOverlay.swift
//  Audiopig
//
//  Global finish celebration overlays (confetti + icon unlock).
//  Lives above the tab shell so finishing a book inside a folder looks
//  identical to finishing one in the root library list.
//

import SwiftUI

struct FinishCelebrationOverlay: ViewModifier {

    let viewModel: LibraryViewModel

    func body(content: Content) -> some View {
        content
            .overlay { confettiOverlay }
            .overlay { iconUnlockOverlay }
            .onChange(of: viewModel.celebratedBook?.id) { _, bookID in
                guard bookID != nil else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            .alert(
                "Delete Audiobook?",
                isPresented: Binding(
                    get: { viewModel.isAutoDeleteConfirmationPresented },
                    set: { if !$0 { viewModel.cancelAutoDelete() } }
                )
            ) {
                Button("Delete", role: .destructive) { viewModel.confirmAutoDelete() }
                Button("Keep", role: .cancel) { viewModel.cancelAutoDelete() }
            } message: {
                Text("\"\(viewModel.pendingAutoDeleteBookTitle)\" was marked finished. Delete it from your library?")
            }
    }

    @ViewBuilder
    private var confettiOverlay: some View {
        if viewModel.celebratedBook != nil {
            ConfettiBurstView {
                viewModel.dismissCelebration()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var iconUnlockOverlay: some View {
        if let tier = viewModel.newlyUnlockedIconTier {
            IconUnlockOverlay(tier: tier) {
                viewModel.dismissIconUnlock()
            }
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }
}

extension View {
    func finishCelebrationOverlay(viewModel: LibraryViewModel) -> some View {
        modifier(FinishCelebrationOverlay(viewModel: viewModel))
    }
}
