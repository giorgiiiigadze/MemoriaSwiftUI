@preconcurrency import AVFoundation
import Combine
import UIKit

/// Drives a custom `AVFoundation` capture session for the in-app camera. UI-facing state
/// (`@Published`) lives on the main actor; the blocking session configuration / capture runs on a
/// dedicated serial queue. The `AVFoundation` objects are `nonisolated(unsafe)` because they're only
/// ever touched from that queue — never concurrently — which keeps them reachable from the
/// `nonisolated` session methods without fighting the project's default main-actor isolation.
@MainActor
final class CameraModel: NSObject, ObservableObject {
    enum Access {
        case unknown, granted, denied
    }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var position: AVCaptureDevice.Position = .back
    @Published var isCapturing = false

    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private var activeInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    nonisolated private let sessionQueue = DispatchQueue(label: "app.memoria.camera.session")

    /// Longest side of the delivered image — a 3:4 cover never needs more, and it keeps the upload
    /// small. Static so the `nonisolated` capture delegate can read it.
    private nonisolated static let maxDimension: CGFloat = 1200

    // MARK: Lifecycle

    /// Requests camera access (prompting only when undetermined) and, if granted, configures and
    /// starts the session.
    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            access = .granted
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            access = granted ? .granted : .denied
        default:
            access = .denied
        }
        guard access == .granted else { return }
        configure(position: position)
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Flips between the rear and front cameras.
    func flip() {
        position = position == .back ? .front : .back
        configure(position: position)
    }

    // MARK: Session configuration

    nonisolated private func configure(position: AVCaptureDevice.Position) {
        sessionQueue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .photo

            if let activeInput { session.removeInput(activeInput) }

            guard
                let device = Self.device(for: position),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            activeInput = input

            if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            if let connection = photoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90 // portrait
                }
                // Mirror the front camera so the saved selfie matches the (mirrored) preview.
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = (position == .front)
                }
            }

            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
        }
    }

    nonisolated private static func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video)
    }

    // MARK: Capture

    /// Captures a still and returns it upright and downscaled, or `nil` on failure.
    nonisolated func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                captureContinuation = continuation
                let settings = AVCapturePhotoSettings()
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let continuation = captureContinuation
        captureContinuation = nil

        guard
            error == nil,
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else {
            continuation?.resume(returning: nil)
            return
        }
        continuation?.resume(returning: image.downscaled(maxDimension: Self.maxDimension))
    }
}

extension UIImage {
    /// Returns a copy whose longest side is at most `maxDimension`, redrawn upright, to keep the
    /// upload small. Images already within bounds are returned unchanged.
    nonisolated func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
