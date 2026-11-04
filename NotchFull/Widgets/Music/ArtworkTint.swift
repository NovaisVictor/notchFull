import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum ArtworkTint {
    private static let context = CIContext()

    /// Average artwork color with brightness and saturation lifted, since raw averages look muddy on black.
    /// `nil` when the image has no bitmap representation to sample.
    static func dominantColor(of image: NSImage) -> NSColor? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let input = CIImage(cgImage: cgImage)

        let filter = CIFilter.areaAverage()
        filter.inputImage = input
        filter.extent = input.extent
        guard let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )

        let average = NSColor(
            srgbRed: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
        return NSColor(
            hue: average.hueComponent,
            saturation: min(average.saturationComponent * 1.3, 1),
            brightness: max(average.brightnessComponent, 0.75),
            alpha: 1
        )
    }
}
