import SwiftUI

/// A compact modal showing the drop's QR code so someone can scan it in person to open the drop.
/// The code encodes the same `https://memoria.app/drop/{id}` link the app already shares. Native
/// sheet chrome — a nav bar with an X to dismiss — over a medium detent.
struct DropQRSheet: View {
    let dropTitle: String
    let linkURL: String

    @Environment(\.dismiss) private var dismiss

    /// Side length of the QR panel — sized to fill the medium detent comfortably.
    private let qrSize: CGFloat = 240

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Spacer()

                QRCodeImage(string: linkURL, size: qrSize)
                    .padding(Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: Radii.xl, style: .continuous)
                            .fill(Colors.white)
                    )

                VStack(spacing: Spacing.xs) {
                    Text(dropTitle)
                        .font(Typography.font(.lg, weight: .strong))
                        .foregroundStyle(Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Scan with a camera to open this drop.")
                        .font(Typography.font(.sm))
                        .foregroundStyle(Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
            .frame(maxWidth: .infinity)
            .navigationTitle("Scan to join")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
