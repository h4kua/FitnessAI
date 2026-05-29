import Foundation

public enum NetworkError: Error, LocalizedError, Sendable {
    case invalidRequest(String)
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case transport(Error)
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message):
            return message
        case .invalidResponse:
            return "The server response could not be understood."
        case .serverError(_, let message):
            return message ?? "The server returned an unexpected error."
        case .transport(let error):
            return error.localizedDescription
        case .unauthorized:
            return "Your session is no longer valid."
        }
    }
}
