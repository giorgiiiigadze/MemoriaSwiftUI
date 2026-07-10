import SwiftUI
import UIKit

/// The Create Drop flow, presented as a modal sheet from the tab bar's "+". Four steps:
/// 1) name, 2) open date, 3) invite friends, 4) take the cover photo. The final step creates the
/// drop (upload cover → insert drop → invite participants) and dismisses.
struct CreateDropView: View {
    /// Called after a drop is successfully created, so the parent can refresh the Home feed.
    var onCreated: () -> Void = {}

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private let service = DropsService()
    private let friendsService = FriendsService()

    private enum Step: Int, CaseIterable { case name, date, invite, cover }

    @State private var step: Step = .name

    // Step 1
    @State private var title = ""
    @FocusState private var nameFocused: Bool
    // Step 2
    @State private var openDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    // Step 3
    @State private var friends: [Friend] = []
    @State private var friendsLoaded = false
    @State private var selectedFriendIDs: Set<UUID> = []
    // Step 4
    @State private var coverImage: UIImage?
    @State private var isShowingCamera = false

    @State private var isCreating = false
    @State private var errorMessage: String?

    private var userID: UUID? { appState.profile?.id }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canAdvance: Bool {
        switch step {
        case .name: return !trimmedTitle.isEmpty
        case .date: return true
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
                        case .name: nameStep
                        case .date: dateStep
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
        .onChange(of: step) { _, newStep in
            nameFocused = newStep == .name
        }
        .onAppear { nameFocused = step == .name }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraView { coverImage = $0 }
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
                    .fill(s.rawValue <= step.rawValue ? Colors.white : Colors.surfaceRaised)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var stepTitle: String {
        switch step {
        case .name: "New Drop"
        case .date: "Opens on"
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
                if step != .name {
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

    // MARK: Step 1 — name

    private var nameStep: some View {
        VStack(spacing: Spacing.lg) {
            Text("Name your drop")
                .font(Typography.font(.xl, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.huge)

            TextField("", text: $title, prompt: Text("Drop name").foregroundStyle(Colors.textPlaceholder))
                .inputFieldStyle()
                .tint(Colors.white)
                .padding(.top, Spacing.lg)
                .textInputAutocapitalization(.words)
                .focused($nameFocused)
                .submitLabel(.next)
                .onSubmit { if !trimmedTitle.isEmpty { withAnimation(.snappy) { goNext() } } }
        }
    }

    // MARK: Step 2 — date

    private var dateStep: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            fieldLabel("When does it open?")
            DatePicker("", selection: $openDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .tint(Colors.white)
                .padding(Spacing.xs)
                .background(Colors.surface, in: RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
        }
    }

    // MARK: Step 3 — invite

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
                                .foregroundStyle(selected ? Colors.white : Colors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Step 4 — cover

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
                onCreated()
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
