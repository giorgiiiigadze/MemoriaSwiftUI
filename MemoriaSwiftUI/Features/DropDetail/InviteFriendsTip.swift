import SwiftUI
import TipKit

/// One-time hint pointing at the Drop Detail header's invite button, so the creator discovers they
/// can add more friends to a drop after it's been created. Dismisses once they tap the button.
struct InviteFriendsTip: Tip {
    var title: Text {
        Text("Add the people who were there, so this memory is captured from every angle.")
            .font(.footnote)
            .foregroundColor(.secondary)
    }

    var message: Text? { nil }
}
