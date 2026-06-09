//
//  CollectionExtensions.swift
//  Audiopig
//

import Foundation

extension Collection {
    /// Returns the element at `index`, or `nil` if the index is out of bounds.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
