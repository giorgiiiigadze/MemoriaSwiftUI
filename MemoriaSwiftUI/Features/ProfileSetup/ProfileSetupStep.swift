import Foundation

enum ProfileSetupStep: Int, CaseIterable {
    case name
    case username
    case photo
    case age
    case phone
    case contacts
    case notifications

    var isSkippable: Bool {
        switch self {
        case .name, .username: false
        case .photo, .age, .phone, .contacts, .notifications: true
        }
    }
}
