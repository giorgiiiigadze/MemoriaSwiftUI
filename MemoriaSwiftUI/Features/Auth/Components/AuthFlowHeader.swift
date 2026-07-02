import SwiftUI

/// Header for the auth flow, mirroring `ProfileSetupHeader`: circular glass back button on the
/// left, centered wordmark, and a glass pill on the right. On the sign-up flow the right pill is
/// "Log in" (route to the login flow); a `nil` `onLogin` hides it (e.g. inside the login flow
/// itself). `onBack` is `nil` on the sign-up flow's first step, which renders an invisible
/// placeholder so the wordmark stays centered.
struct AuthFlowHeader: View {
    var onBack: (() -> Void)?
    var onLogin: (() -> Void)?

    var body: some View {
        ZStack {
            Text("Memoria")
                .font(Typography.font(.xl, weight: .strong))
                .foregroundStyle(Colors.textPrimary)

            HStack {
                GlassHeaderIconButton(systemImage: "chevron.left", action: onBack)
                Spacer()
                if let onLogin {
                    GlassHeaderPillButton(title: "Log in", action: onLogin)
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, Spacing.sm)
    }
}

#Preview {
    ZStack {
        Colors.background.ignoresSafeArea()
        VStack(spacing: Spacing.xl) {
            AuthFlowHeader(onBack: nil, onLogin: {})
            AuthFlowHeader(onBack: {}, onLogin: {})
            AuthFlowHeader(onBack: {}, onLogin: nil)
        }
    }
}
