import Foundation

public struct HTTPResponse: Sendable, Equatable {
    public let body: Data
    public let headers: [String: String]
    public let statusCode: Int

    public init(
        body: Data,
        headers: [String: String],
        statusCode: Int
    ) {
        self.body = body
        self.headers = headers
        self.statusCode = statusCode
    }
}
