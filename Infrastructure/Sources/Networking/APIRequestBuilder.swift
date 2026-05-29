import Foundation

public struct APIRequestBuilder: Sendable {
    private let configuration: APIConfiguration

    public init(configuration: APIConfiguration) {
        self.configuration = configuration
    }

    public func build(
        endpoint: APIEndpoint,
        additionalHeaders: [String: String] = [:]
    ) throws -> APIRequest {
        guard var components = URLComponents(
            url: configuration.apiBaseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidRequest("Unable to create URL components for \(endpoint.path).")
        }

        if endpoint.queryItems.isEmpty == false {
            components.queryItems = endpoint.queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidRequest("Unable to resolve URL for \(endpoint.path).")
        }

        var headers = endpoint.headers
        for (key, value) in additionalHeaders {
            headers[key] = value
        }

        return APIRequest(
            url: url,
            method: endpoint.method,
            headers: headers,
            body: endpoint.body,
            timeoutInterval: configuration.requestTimeout
        )
    }
}
