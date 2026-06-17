//
//  ThumbnailEncoder.swift
//  Audiopig
//

import UIKit

enum ThumbnailEncoder {
  enum Size {
    case list
    case player

    var maxDimension: CGFloat {
      switch self {
      case .list: return 120
      case .player: return 200
      }
    }
  }

  static func jpegData(from image: UIImage, size: Size, quality: CGFloat = 0.6) -> Data? {
    let scaled = resized(image, maxDimension: size.maxDimension)
    return scaled.jpegData(compressionQuality: quality)
  }

  private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size
    guard size.width > 0, size.height > 0 else { return image }
    let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
    guard scale < 1 else { return image }
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: newSize))
    }
  }
}
