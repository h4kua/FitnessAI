import Foundation

public struct APIRequest: Sendable, Equatable {
    public let body: Data?
    public let headers: [String: String]
    public let method: HTTPMethod
    public let timeoutInterval: TimeInterval
    public let url: URL

    public init(
        url: URL,
        method: HTTPMethod,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
    }
}
