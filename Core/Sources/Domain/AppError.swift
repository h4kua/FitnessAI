import Foundation

public enum AppError: Error, LocalizedError, Sendable {
    case authorizationDenied(String)
    case dataUnavailable(String)
    case invalidConfiguration(String)
    case rateLimited(String)
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied(let message),
             .dataUnavailable(let message),
             .invalidConfiguration(let message),
             .rateLimited(let message),
             .unavailable(let message):
            return message
        }
    }
}
