import SwiftUI

/// A compact "how it works" explainer shown under the first-drop card for brand-new users: three
/// SF Symbol-led steps that teach the core drop loop (create → invite → reveal). Each step is an
/// icon + primary title on one line, with a secondary line beneath. App-styled with the design
/// tokens, so it reads as part of the empty-state onboarding.
struct HowItWorksSteps: View {
    /// Icon glyph point size.
    private let iconSize: CGFloat = 20

    private struct Step {
        let icon: String
        let title: String
        let subtitle: String
    }

    private let steps: [Step] = [
        Step(icon: "camera.viewfinder", title: "Create a drop", subtitle: "Start a shared photo capsule."),
        Step(icon: "person.2.fill", title: "Invite your friends", subtitle: "Everyone adds their own photos."),
        Step(icon: "sparkles", title: "Open it together", subtitle: "Reveal all the memories at once."),
    ]

    var body: some View {
        VStack(alignment: .center, spacing: Spacing.lg) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                row(step)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ step: Step) -> some View {
        VStack(alignment: .center, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: step.icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Colors.white)
                Text(step.title)
                    .font(Typography.font(.md, weight: .semiBold))
                    .foregroundStyle(Colors.textPrimary)
            }

            Text(step.subtitle)
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HowItWorksSteps()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Colors.background)
        .preferredColorScheme(.dark)
}
