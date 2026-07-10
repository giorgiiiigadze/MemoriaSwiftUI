import SwiftUI

/// A one-time onboarding tile shown on the Home feed to a brand-new user who hasn't created a drop
/// yet (gated by `profile.hasCreatedFirstDrop`). Sized like a `DropCard` — full-width, 3:4 — with a
/// blurred asset image as its full-bleed background, a dark scrim for legibility, and a personalized
/// "Hey {name}" prompt overlaid. The `CompactPillButton` (matching the Profile/Calendar empty states)
/// opens the Create Drop flow. Copy mirrors the RN Home screen's first-drop card.
struct CreateFirstDropCard: View {
    /// The greeting name — the user's display name (or handle), already resolved by the caller.
    let name: String
    let action: () -> Void

    /// Name of the Assets-catalog image used as the card's blurred background. Add an image set with
    /// this exact name to `Assets.xcassets`.
    private let illustrationName = "FirstDropIllustration"

    /// Gaussian blur applied to the background image.
    private let backgroundBlur: CGFloat = 14

    var body: some View {
        // `Color.clear` fixes the 3:4 box (matching `DropCard`'s photo), so the tile keeps the
        // exact card proportions regardless of its contents. The `CompactPillButton` inside is the
        // tap target (like the Profile/Calendar empty states), so the card itself isn't a Button.
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { background }
            .overlay { scrim }
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
    }

    /// Blurred, edge-to-edge background photo (on the deep surface, so a missing asset still reads).
    private var background: some View {
        Image(illustrationName)
            .resizable()
            .scaledToFill()
            .blur(radius: backgroundBlur)
            .background(Colors.surfaceDeep)
    }

    /// Darkening gradient so the white copy stays readable over any photo.
    private var scrim: some View {
        LinearGradient(
            colors: [.black.opacity(0.25), .black.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var content: some View {
        VStack(spacing: Spacing.xl) {
            VStack(spacing: Spacing.sm) {
                Text("Hey \(name)")
                    .font(Typography.font(.xxxxl, weight: .bold))
                    .foregroundStyle(Colors.white)
                    .multilineTextAlignment(.center)
                Text("It's time to create your first drop\nand start sharing memories with friends")
                    .font(Typography.font(.lg))
                    .foregroundStyle(Colors.white)
                    .multilineTextAlignment(.center)
            }

            // Same button as the Profile/Calendar empty states.
            CompactPillButton(title: "Create a drop", systemImage: "camera.viewfinder", action: action)
        }
        .padding(.horizontal, Spacing.xl)
    }
}

#Preview {
    CreateFirstDropCard(name: "Giorgi", action: {})
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Colors.background)
        .preferredColorScheme(.dark)
}
