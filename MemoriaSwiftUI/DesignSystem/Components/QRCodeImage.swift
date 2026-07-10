import SwiftUI
import CoreImage.CIFilterBuiltins

/// Renders a string as a scannable QR code. Uses CoreImage's built-in generator (no dependency) and
/// upscales the tiny raw output with nearest-neighbor interpolation so the modules stay crisp at any
/// size. Black modules on a transparent background — frame it on a light surface for scan contrast.
struct QRCodeImage: View {
    let string: String
    let size: CGFloat

    /// One shared context — creating a `CIContext` per render is expensive.
    private static let context = CIContext()

    var body: some View {
        if let cgImage = Self.makeQR(from: string) {
            Image(decorative: cgImage, scale: 1)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
        } else {
            // Generation only fails on pathological input; show a neutral placeholder rather than crash.
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(Colors.textTertiary)
        }
    }

    private static func makeQR(from string: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        // Scale the ~25pt output up to a comfortably high-resolution bitmap so it stays sharp.
        let scale = RenderScale.target / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return context.createCGImage(scaled, from: scaled.extent)
    }

    /// Target pixel width for the rendered bitmap — large enough to stay crisp on any display.
    private enum RenderScale {
        static let target: CGFloat = 1024
    }
}
