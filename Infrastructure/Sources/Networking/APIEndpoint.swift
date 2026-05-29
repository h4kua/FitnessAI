import Foundation

public struct APIEndpoint: Sendable, Equatable {
    public let body: Data?
    public let headers: [String: String]
    public let method: HTTPMethod
    public let path: String
    public let queryItems: [URLQueryItem]
    public let requiresAuthorization: Bool

    public init(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        requiresAuthorization: Bool = true
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.requiresAuthorization = requiresAuthorization
    }
}
