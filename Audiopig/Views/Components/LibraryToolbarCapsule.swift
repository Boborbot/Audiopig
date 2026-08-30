//
//  LibraryToolbarCapsule.swift
//  Audiopig
//

import SwiftUI

/// Order, transcription queue, and search controls grouped in a library header capsule.
struct LibraryToolbarCapsule: View {
    let viewModel: LibraryViewModel
    @Binding var isOrderPresented: Bool

    private var showsQueueBadge: Bool {
        viewModel.hasTranscriptionQueueUI && viewModel.transcriptionQueueCount > 0
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Button {
                isOrderPresented.toggle()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Order files")
            .popover(isPresented: $isOrderPresented, arrowEdge: .top) {
                LibraryOrderMenuContent(viewModel: viewModel)
                    .presentationCompactAdaptation(.popover)
                    .presentationBackground(.regularMaterial)
            }

            if viewModel.hasTranscriptionQueueUI {
                Button {
                    viewModel.presentTranscriptionQueue()
                } label: {
                    Image(systemName: "text.append")
                        .frame(width: 28, height: 28)
                        .overlay(alignment: .topTrailing) {
                            if viewModel.transcriptionQueueCount > 0 {
                                Text("\(viewModel.transcriptionQueueCount)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(DS.Color.coral))
                                    .fixedSize()
                                    .offset(x: 8, y: -5)
                            }
                        }
                }
                .accessibilityLabel("Transcription queue, \(viewModel.transcriptionQueueCount) books")
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                withAnimation(DS.Animation.standard) {
                    viewModel.isSearchActive = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Search library")
        }
        .font(.body.weight(.medium))
        .foregroundStyle(DS.Color.primary)
        .padding(.horizontal, DS.Spacing.sm + 2)
        .padding(.vertical, showsQueueBadge ? DS.Spacing.xs + 2 : DS.Spacing.xs)
        .background {
            Capsule()
                .fill(DS.Color.secondarySurface)
                .applyShadows(DS.Shadow.card)
        }
        .animation(DS.Animation.standard, value: viewModel.hasTranscriptionQueueUI)
    }
}
