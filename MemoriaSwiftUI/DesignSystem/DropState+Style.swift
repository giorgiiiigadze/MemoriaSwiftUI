import SwiftUI

extension DropState {
    var color: Color {
        switch self {
        case .active: Colors.stateActive
        case .ready: Colors.stateReady
        case .open: Colors.stateOpen
        case .expired: Colors.stateExpired
        }
    }

    var label: String {
        switch self {
        case .active: "Collecting"
        case .ready: "Ready"
        case .open: "Open"
        case .expired: "Expired"
        }
    }
}
