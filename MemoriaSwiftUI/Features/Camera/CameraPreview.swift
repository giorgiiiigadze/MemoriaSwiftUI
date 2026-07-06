import AVFoundation
import SwiftUI

/// A SwiftUI wrapper around `AVCaptureVideoPreviewLayer` — the live camera feed. `resizeAspectFill`
/// fills its (3:4) frame; since a portrait still is already 3:4, what's shown is what's captured.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90 // portrait
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    /// A `UIView` backed directly by an `AVCaptureVideoPreviewLayer`, so the preview resizes with the
    /// view instead of needing manual frame syncing.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
