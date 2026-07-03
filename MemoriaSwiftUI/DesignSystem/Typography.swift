import SwiftUI

enum Typography {
    enum Weight {
        case regular // 400
        case medium // 500
        case semiBold // 600
        case strong // 700
        case bold // 800

        var fontWeight: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .semiBold: .semibold
            case .strong: .bold
            case .bold: .heavy
            }
        }
    }

    enum Size: CGFloat {
        case xs = 12
        case sm = 14
        case body = 15
        case md = 16
        case lg = 18
        case xl = 22
        case xxl = 28
        case xxxl = 38
    }

    static func font(_ size: Size, weight: Weight = .regular) -> Font {
        .system(size: size.rawValue, weight: weight.fontWeight)
    }
}
