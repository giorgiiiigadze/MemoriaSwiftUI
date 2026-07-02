import PhotosUI
import SwiftUI

struct PhotoStepView: View {
    @Environment(ProfileSetupStore.self) private var store
    let onContinue: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var previewData: Data?
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Add a profile photo")
                .font(Typography.font(.xl, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)
                .padding(.top, Spacing.xxl)

            Text("Optional — you can always add one later.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                PhotoPickerLabel(name: store.name, previewData: previewData, isUploading: isUploading)
            }
            .disabled(isUploading)
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await load(newItem) }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.error)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            ProfileSetupContinueButton(isLoading: isUploading, action: onContinue)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }

    private func load(_ item: PhotosPickerItem) async {
        errorMessage = nil
        isUploading = true
        defer { isUploading = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Couldn't load that photo — try another."
                return
            }
            previewData = data
            _ = try await store.uploadAvatar(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PhotoPickerLabel: View {
    let name: String
    let previewData: Data?
    let isUploading: Bool

    var body: some View {
        ZStack {
            InitialAvatar(
                name: name,
                size: 120,
                backgroundColor: Colors.surfaceInput,
                foregroundColor: Colors.textPrimary,
                imageData: previewData
            )
            if isUploading {
                Circle()
                    .fill(Colors.ink.opacity(0.35))
                    .frame(width: 120, height: 120)
                ProgressView().tint(Colors.white)
            }
        }
    }
}

#Preview {
    PhotoStepView(onContinue: {})
        .environment(ProfileSetupStore(userID: UUID()))
        .background(Colors.background)
}
