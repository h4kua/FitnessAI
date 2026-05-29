import Foundation

public actor URLSessionHTTPClient: HTTPClient {
    private let logger: AppLogger
    private let session: URLSession

    public init(logger: AppLogger) {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
        self.logger = logger
    }

    public func send(_ request: APIRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpBody = request.body
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeoutInterval

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            let headerFields = httpResponse.allHeaderFields.reduce(into: [String: String]()) { partialResult, entry in
                guard let key = entry.key as? String else { return }
                partialResult[key] = String(describing: entry.value)
            }

            logger.info("HTTP \(request.method.rawValue) \(request.url.absoluteString) -> \(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                throw NetworkError.unauthorized
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = data.isEmpty ? nil : String(data: data, encoding: .utf8)
                throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: message)
            }

            return HTTPResponse(
                body: data,
                headers: headerFields,
                statusCode: httpResponse.statusCode
            )
        } catch let error as NetworkError {
            throw error
        } catch {
            logger.error("Transport failure for \(request.url.absoluteString): \(error.localizedDescription)")
            throw NetworkError.transport(error)
        }
    }
}
