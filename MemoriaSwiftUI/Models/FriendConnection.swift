import Foundation

/// The current user's friend graph, partitioned for the Friends tab. `friends` are accepted (both
/// directions collapsed to the other person); `incoming` are pending requests awaiting my response;
/// `outgoing` are pending requests I've sent. Mirrors the RN `useFriends` hook's shape.
struct FriendConnections: Sendable, Hashable {
    var friends: [Friend] = []
    var incoming: [FriendRequest] = []
    var outgoing: [FriendRequest] = []
}

/// An accepted friend: the other person's profile plus when the friendship was established.
struct Friend: Identifiable, Sendable, Hashable {
    let profile: DropWithParticipants.ProfileRef
    let since: Date
    var id: UUID { profile.id }
}

/// A pending friendship, carrying the row id (needed to accept/decline) and the other party.
struct FriendRequest: Identifiable, Sendable, Hashable {
    let friendshipID: UUID
    let profile: DropWithParticipants.ProfileRef
    var id: UUID { friendshipID }
}
