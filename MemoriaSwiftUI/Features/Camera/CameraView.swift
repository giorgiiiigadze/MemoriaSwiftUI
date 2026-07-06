import AVFoundation
import SwiftUI

/// A custom in-app camera (replaces the system `UIImagePickerController`): a full-screen black
/// stage with a centered 3:4 live preview, a native transparent header (Liquid Glass chevron-down
/// dismiss on the left, "Memoria" wordmark centered), and a BeReal-style shutter with a flip
/// control. Hands the captured, upright, downscaled image back via `onCapture`, then dismisses.
struct CameraView: View {
    /// Async so the camera can stay up showing a loading state while the caller does the real work
    /// (e.g. uploading the photo), dismissing only once it finishes. Instant callers (setting a cover
    /// image) return immediately, so no loader is perceptible there.
    var onCapture: (UIImage) async -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = CameraModel()

    /// True from the shutter tap until the capture + caller's work completes; shows the loading
    /// overlay and blocks a second shot.
    @State private var isFinishing = false

    /// Shutter dimensions (BeReal's white ring around a white disc).
    private let shutterOuter: CGFloat = 76
    private let shutterInner: CGFloat = 62

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch model.access {
                case .granted:
                    CameraPreview(session: model.session)
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()
                case .denied:
                    permissionDenied
                case .unknown:
                    EmptyView()
                }

                VStack {
                    Spacer()
                    if model.access == .granted { controls }
                }

                // Loading state: black screen + spinner from the shutter tap until the caller's work
                // (e.g. the upload) finishes, so the camera doesn't blink shut before it's done.
                if isFinishing {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        loadingSymbol
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isFinishing)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Memoria")
                        .font(Typography.font(.xl, weight: .strong))
                        .foregroundStyle(Colors.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(Colors.white)
        }
        .preferredColorScheme(.dark)
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

    /// Loading indicator: the `photo.stack` symbol with the sequential variable-color shimmer —
    /// the system's canonical "working" animation. Loops smoothly on its own and stays fully
    /// visible (iOS 17+).
    private var loadingSymbol: some View {
        Image(systemName: "photo.stack")
            .font(.system(size: 56))
            .foregroundStyle(Colors.white)
            .symbolEffect(.variableColor.iterative, options: .repeating)
    }

    // MARK: Controls

    private var controls: some View {
        ZStack {
            shutterButton

            HStack {
                Spacer()
                flipButton
            }
            .padding(.horizontal, Spacing.xxl)
        }
        .padding(.bottom, Spacing.xxxl)
    }

    private var shutterButton: some View {
        Button(action: capture) {
            ZStack {
                Circle()
                    .strokeBorder(Colors.white, lineWidth: 4)
                    .frame(width: shutterOuter, height: shutterOuter)
                Circle()
                    .fill(Colors.white)
                    .frame(width: shutterInner, height: shutterInner)
            }
            .opacity(model.isCapturing ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(model.isCapturing)
    }

    private var flipButton: some View {
        Button { model.flip() } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Colors.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isCapturing)
    }

    // MARK: Permission

    private var permissionDenied: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: 32))
                .foregroundStyle(Colors.white)
            Text("Camera access needed")
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.white)
            Text("Enable camera access in Settings to take a photo.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(Typography.font(.body, weight: .semiBold))
                    .foregroundStyle(Colors.ink)
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.xl)
                    .background(Colors.white, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.xl)
    }

    // MARK: Actions

    private func capture() {
        guard !model.isCapturing, !isFinishing else { return }
        Task {
            model.isCapturing = true
            let image = await model.capturePhoto()
            model.isCapturing = false
            guard let image else { return }
            // Keep the camera up under a loading overlay while the caller does its work, then dismiss.
            isFinishing = true
            await onCapture(image)
            dismiss()
        }
    }
}
