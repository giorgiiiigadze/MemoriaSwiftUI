import Foundation

extension Error {
    /// Whether this error is just an aborted async operation rather than a real failure — a Swift
    /// `CancellationError`, or the URLSession equivalent (`NSURLErrorCancelled` / code `-999`) that
    /// Supabase surfaces when its request is cancelled. Fast tab switches and changing `.task(id:)`
    /// tear down in-flight loads this way, so callers should stay silent instead of showing a
    /// "couldn't load" error for them.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    /// Whether this looks like a transient connectivity failure (offline, timed out, connection
    /// lost, host unreachable) rather than a definitive server/auth rejection. Lets boot/hydration
    /// keep a valid session instead of tearing it down just because the network is unreachable.
    var isConnectivityError: Bool {
        let nsError = self as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorTimedOut,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed,
             NSURLErrorResourceUnavailable,
             NSURLErrorDataNotAllowed,
             NSURLErrorInternationalRoamingOff,
             NSURLErrorSecureConnectionFailed:
            return true
        default:
            return false
        }
    }
}
