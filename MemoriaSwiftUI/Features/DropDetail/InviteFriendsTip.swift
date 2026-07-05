import SwiftUI
import TipKit

/// One-time hint pointing at the Drop Detail header's invite button, so the creator discovers they
/// can add more friends to a drop after it's been created. Dismisses once they tap the button.
struct InviteFriendsTip: Tip {
    var title: Text {
        Text("Invite friends")
    }

    var message: Text? {
        Text("Add more friends to this drop so everyone can share photos.")
    }
}
