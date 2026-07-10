import Foundation

/// The app's custom-scheme deep links (`memoria://…`). One source of truth for both building the
/// links we encode (e.g. a drop's QR code) and parsing the ones iOS hands back via `.onOpenURL`.
/// The scheme is registered under `CFBundleURLTypes` in `Info-Secrets.plist`.
enum DeepLink {
    static let scheme = "memoria"
    static let dropHost = "drop"

    /// The scannable link to a drop, e.g. `memoria://drop/<uuid>` — encoded in the drop's QR code.
    static func drop(_ id: UUID) -> URL {
        URL(string: "\(scheme)://\(dropHost)/\(id.uuidString.lowercased())")!
    }

    /// The drop id inside an incoming `memoria://drop/<uuid>` link, or nil if it isn't one.
    static func dropID(from url: URL) -> UUID? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == dropHost else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
