import SwiftUI
import UIKit

/// The Create Drop flow (step 6), presented as a modal sheet from the tab bar's "+". Three steps:
/// 1) name + open date, 2) invite friends, 3) take the cover photo. The final step creates the
/// drop (upload cover → insert drop → invite participants) and dismisses.
struct CreateDropView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private let service = DropsService()
    private let friendsService = FriendsService()

    private enum Step: Int, CaseIterable { case details, invite, cover }

    @State private var step: Step = .details

    // Step 1
    @State private var title = ""
    @State private var openDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    // Step 2
    @State private var friends: [Friend] = []
    @State private var friendsLoaded = false
    @State private var selectedFriendIDs: Set<UUID> = []
    // Step 3
    @State private var coverImage: UIImage?
    @State private var isShowingCamera = false

    @State private var isCreating = false
    @State private var errorMessage: String?

    private var userID: UUID? { appState.profile?.id }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canAdvance: Bool {
        switch step {
        case .details: return !trimmedTitle.isEmpty
        case .invite: return true
        case .cover: return coverImage != nil && !isCreating
        }
    }

    var body: some View {
        ZStack {
            Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                progress

                ScrollView {
                    Group {
                        switch step {
                        case .details: detailsStep
                        case .invite: inviteStep
                        case .cover: coverStep
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xl)
                }

                footer
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadFriends() }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { coverImage = $0 }
                .ignoresSafeArea()
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        ZStack {
            Text(stepTitle)
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)

            HStack {
                Button("Cancel") { dismiss() }
                    .font(Typography.font(.body))
                    .foregroundStyle(Colors.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    private var progress: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Colors.accent : Colors.surfaceRaised)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var stepTitle: String {
        switch step {
        case .details: "New Drop"
        case .invite: "Invite Friends"
        case .cover: "Add a Cover"
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.error)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: Spacing.md) {
                if step != .details {
                    Button {
                        withAnimation(.snappy) { goBack() }
                    } label: {
                        Text("Back")
                            .font(Typography.font(.body, weight: .semiBold))
                            .foregroundStyle(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if step == .cover { create() } else { withAnimation(.snappy) { goNext() } }
                } label: {
                    Group {
                        if isCreating {
                            ProgressView().tint(Colors.ink)
                        } else {
                            Text(step == .cover ? "Create Drop" : "Next")
                                .font(Typography.font(.body, weight: .semiBold))
                        }
                    }
                    .foregroundStyle(Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Colors.white, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
                    .opacity(canAdvance ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canAdvance)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.lg)
    }

    // MARK: Step 1 — details

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                fieldLabel("Name")
                TextField("", text: $title, prompt: Text("What's this drop about?")
                    .foregroundColor(Colors.textPlaceholder))
                    .font(Typography.font(.body))
                    .foregroundStyle(Colors.textPrimary)
                    .padding(Spacing.md)
                    .background(Colors.surfaceInput, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                fieldLabel("Opens on")
                DatePicker("", selection: $openDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .tint(Colors.accent)
                    .padding(Spacing.xs)
                    .background(Colors.surface, in: RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
            }
        }
    }

    // MARK: Step 2 — invite

    @ViewBuilder
    private var inviteStep: some View {
        if !friendsLoaded {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in FriendRowSkeleton() }
            }
        } else if friends.isEmpty {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Colors.white)
                    .padding(.bottom, Spacing.xxs)
                Text("No friends yet")
                    .font(Typography.font(.md, weight: .semiBold))
                    .foregroundStyle(Colors.white)
                Text("You can invite people after adding friends.")
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.xxxxl)
        } else {
            VStack(spacing: 0) {
                ForEach(friends) { friend in
                    let selected = selectedFriendIDs.contains(friend.id)
                    Button {
                        toggle(friend.id)
                    } label: {
                        FriendRow(profile: friend.profile) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(selected ? Colors.accent : Colors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Step 3 — cover

    private var coverStep: some View {
        VStack(spacing: Spacing.lg) {
            Text("Take a cover photo for your drop.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                isShowingCamera = true
            } label: {
                ZStack {
                    if let coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Colors.surface
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Colors.textSecondary)
                            Text("Tap to take photo")
                                .font(Typography.font(.sm, weight: .medium))
                                .foregroundStyle(Colors.textSecondary)
                        }
                    }
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
                .overlay {
                    if coverImage == nil {
                        RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
                            .strokeBorder(Colors.borderDefault, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    }
                }
            }
            .buttonStyle(.plain)

            if coverImage != nil {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Retake", systemImage: "arrow.triangle.2.circlepath")
                        .font(Typography.font(.sm, weight: .medium))
                        .foregroundStyle(Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Building blocks

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.font(.sm, weight: .semiBold))
            .foregroundStyle(Colors.textSecondary)
    }

    // MARK: Actions

    private func goNext() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
    }

    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) { step = prev }
    }

    private func toggle(_ id: UUID) {
        if selectedFriendIDs.contains(id) { selectedFriendIDs.remove(id) } else { selectedFriendIDs.insert(id) }
    }

    private func loadFriends() async {
        guard let userID else { return }
        friends = (try? await friendsService.fetchConnections(userID: userID))?.friends ?? []
        friendsLoaded = true
    }

    private func create() {
        guard let userID, let coverImage,
              let data = coverImage.jpegData(compressionQuality: 0.7) else { return }
        errorMessage = nil
        isCreating = true
        Task {
            do {
                try await service.createDrop(
                    creatorID: userID,
                    title: trimmedTitle,
                    openDate: openDate,
                    thumbnail: data,
                    invitedUserIDs: Array(selectedFriendIDs)
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
}

#Preview {
    CreateDropView()
        .environment(AppState())
}
