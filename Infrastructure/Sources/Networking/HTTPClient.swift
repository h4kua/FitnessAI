public protocol HTTPClient: Sendable {
    func send(_ request: APIRequest) async throws -> HTTPResponse
}
