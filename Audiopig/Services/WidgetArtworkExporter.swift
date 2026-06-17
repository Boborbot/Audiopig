//
//  WidgetArtworkExporter.swift
//  Audiopig
//
//  Writes a widget-sized cover thumbnail and derived theme colors into the App Group container.
//

import CoreImage
import UIKit

enum WidgetArtworkExporter {

    private static let maxCoverDimension: CGFloat = 320
    private static let jpegQuality: CGFloat = 0.82

    static func exportCover(image: UIImage?) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetListeningSnapshot.appGroupID
        ) else { return }

        let url = container.appendingPathComponent(WidgetListeningSnapshot.coverArtworkFilename)

        guard let image else {
            WidgetListeningSnapshot.clearCoverArtwork()
            WidgetListeningSnapshot.saveTheme(.fallback)
            return
        }

        let thumbnail = resized(image, maxDimension: maxCoverDimension)
        let theme = makeTheme(from: thumbnail)
        WidgetListeningSnapshot.saveTheme(theme)

        guard let jpeg = thumbnail.jpegData(compressionQuality: jpegQuality) else { return }
        try? jpeg.write(to: url, options: .atomic)
    }

    // MARK: - Theme

    private static func makeTheme(from image: UIImage) -> WidgetListeningSnapshot.Theme {
        let average = averageRGB(of: image) ?? (red: 0.55, green: 0.45, blue: 0.40)
        let background = blend(average, toward: (0, 0, 0), amount: 0.42)
        let accent = blend(average, toward: (1, 1, 1), amount: 0.08)
        let luminance = relativeLuminance(background)

        let primary: (Double, Double, Double)
        let secondary: (Double, Double, Double)
        if luminance < 0.42 {
            primary = (1, 1, 1)
            secondary = (0.86, 0.86, 0.88)
        } else {
            primary = (0.10, 0.10, 0.12)
            secondary = (0.34, 0.34, 0.38)
        }

        return WidgetListeningSnapshot.Theme(
            background: rgb(background),
            accent: rgb(accent),
            primaryText: WidgetListeningSnapshot.RGB(red: primary.0, green: primary.1, blue: primary.2),
            secondaryText: WidgetListeningSnapshot.RGB(red: secondary.0, green: secondary.1, blue: secondary.2)
        )
    }

    private static func averageRGB(of image: UIImage) -> (red: Double, green: Double, blue: Double)? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let params: [String: Any] = [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
        ]
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: params),
              let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext().render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return (
            red: Double(bitmap[0]) / 255,
            green: Double(bitmap[1]) / 255,
            blue: Double(bitmap[2]) / 255
        )
    }

    // MARK: - Image

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        guard scale < 1 else { return image }

        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    // MARK: - Color math

    private static func blend(
        _ color: (red: Double, green: Double, blue: Double),
        toward target: (Double, Double, Double),
        amount: Double
    ) -> (red: Double, green: Double, blue: Double) {
        (
            red: color.red + (target.0 - color.red) * amount,
            green: color.green + (target.1 - color.green) * amount,
            blue: color.blue + (target.2 - color.blue) * amount
        )
    }

    private static func relativeLuminance(_ color: (red: Double, green: Double, blue: Double)) -> Double {
        0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
    }

    private static func rgb(_ color: (red: Double, green: Double, blue: Double)) -> WidgetListeningSnapshot.RGB {
        WidgetListeningSnapshot.RGB(red: color.red, green: color.green, blue: color.blue)
    }
}
