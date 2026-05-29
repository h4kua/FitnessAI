import Foundation

public struct AppEnvironment: Sendable, Equatable {
    public let analyticsBaseURL: URL?
    public let apiBaseURL: URL?
    public let apiNinjasKey: String?
    /// Groq API key (env var: GROK_ENV). Used for on-device coaching cue generation.
    public let groqApiKey: String?
    public let appName: String
    public let buildConfiguration: String
    public let bundleIdentifier: String
    public let graphQLEnabled: Bool
    public let requestTimeout: TimeInterval
    public let usesDemoHealthData: Bool

    public init(
        analyticsBaseURL: URL?,
        apiBaseURL: URL?,
        apiNinjasKey: String?,
        groqApiKey: String?,
        appName: String,
        buildConfiguration: String,
        bundleIdentifier: String,
        graphQLEnabled: Bool,
        requestTimeout: TimeInterval,
        usesDemoHealthData: Bool
    ) {
        self.analyticsBaseURL = analyticsBaseURL
        self.apiBaseURL = apiBaseURL
        self.apiNinjasKey = apiNinjasKey
        self.groqApiKey = groqApiKey
        self.appName = appName
        self.buildConfiguration = buildConfiguration
        self.bundleIdentifier = bundleIdentifier
        self.graphQLEnabled = graphQLEnabled
        self.requestTimeout = requestTimeout
        self.usesDemoHealthData = usesDemoHealthData
    }
}

public extension AppEnvironment {
    static func live(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) -> AppEnvironment {
        let infoDictionary = bundle.infoDictionary ?? [:]
        let appName = infoDictionary["CFBundleDisplayName"] as? String
            ?? infoDictionary["CFBundleName"] as? String
            ?? "FitnessCoach"
        let bundleIdentifier = bundle.bundleIdentifier ?? "com.example.fitnesscoach"
        let buildConfiguration = processInfo.environment["XCODE_CONFIGURATION"]
            ?? processInfo.environment["CONFIGURATION"]
            ?? "Debug"
        let analyticsBaseURL = stringValue(
            forKey: "ANALYTICS_BASE_URL",
            infoDictionary: infoDictionary,
            processInfo: processInfo
        ).flatMap(resolvedURL(from:))
        let apiBaseURL = stringValue(
            forKey: "API_BASE_URL",
            infoDictionary: infoDictionary,
            processInfo: processInfo
        ).flatMap(resolvedURL(from:))
        let graphQLEnabled = boolValue(
            forKey: "GRAPHQL_ENABLED",
            infoDictionary: infoDictionary,
            processInfo: processInfo
        )
        let requestTimeout = stringValue(
            forKey: "API_REQUEST_TIMEOUT",
            infoDictionary: infoDictionary,
            processInfo: processInfo
        ).flatMap(TimeInterval.init) ?? 30
        let usesDemoHealthData = boolValue(
            forKey: "USE_DEMO_HEALTH_DATA",
            infoDictionary: infoDictionary,
            processInfo: processInfo
        )
        let apiNinjasKey = stringValue(
            forKey: "API_NINJAS_KEY",
            infoDictionary: infoDictionary,
            processInfo: processInfo
        )
        // Key variable name in .env is GROK_ENV (Groq inference API)
        let groqApiKey = stringValue(
            forKey: "GROK_ENV",
            infoDictionary: infoDictionary,
            processInfo: processInfo
        )

        return AppEnvironment(
            analyticsBaseURL: analyticsBaseURL,
            apiBaseURL: apiBaseURL,
            apiNinjasKey: apiNinjasKey,
            groqApiKey: groqApiKey,
            appName: appName,
            buildConfiguration: buildConfiguration,
            bundleIdentifier: bundleIdentifier,
            graphQLEnabled: graphQLEnabled,
            requestTimeout: requestTimeout,
            usesDemoHealthData: usesDemoHealthData
        )
    }

    var apiConfiguration: APIConfiguration? {
        guard let apiBaseURL, Self.isUsableRemoteURL(apiBaseURL) else {
            return nil
        }

        return APIConfiguration(
            analyticsBaseURL: analyticsBaseURL.flatMap { analyticsURL in
                Self.isUsableRemoteURL(analyticsURL) ? analyticsURL : nil
            },
            apiBaseURL: apiBaseURL,
            requestTimeout: requestTimeout,
            supportsGraphQL: graphQLEnabled
        )
    }
}

private extension AppEnvironment {
    static func stringValue(
        forKey key: String,
        infoDictionary: [String: Any],
        processInfo: ProcessInfo
    ) -> String? {
        if let value = processInfo.environment[key], value.isEmpty == false {
            return value
        }

        if let value = infoDictionary[key] as? String, value.isEmpty == false {
            return value
        }

        return nil
    }

    static func resolvedURL(from rawValue: String) -> URL? {
        guard rawValue.contains("$(") == false else {
            return nil
        }

        guard let url = URL(string: rawValue) else {
            return nil
        }

        return rewriteLoopbackURLIfNeeded(url)
    }

    static func isUsableRemoteURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), host.isEmpty == false else {
            return false
        }

        if host == "example.com" || host.hasSuffix(".example.com") {
            return false
        }

        if host == "example.org" || host.hasSuffix(".example.org") {
            return false
        }

        if host == "example.net" || host.hasSuffix(".example.net") {
            return false
        }

        return true
    }

    static func rewriteLoopbackURLIfNeeded(_ url: URL) -> URL {
        guard shouldRewriteLoopbackHost,
              let host = url.host?.lowercased(),
              host == "localhost" || host == "127.0.0.1",
              let fallbackHost = stringValue(
                  forKey: "LOCALHOST_FALLBACK_HOST",
                  infoDictionary: Bundle.main.infoDictionary ?? [:],
                  processInfo: .processInfo
              )
        else {
            return url
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        components.host = fallbackHost
        return components.url ?? url
    }

    static var shouldRewriteLoopbackHost: Bool {
#if targetEnvironment(simulator)
        false
#elseif os(iOS)
        true
#else
        false
#endif
    }

    static func boolValue(
        forKey key: String,
        infoDictionary: [String: Any],
        processInfo: ProcessInfo
    ) -> Bool {
        guard let value = stringValue(
            forKey: key,
            infoDictionary: infoDictionary,
            processInfo: processInfo
        ) else {
            return false
        }

        switch value.lowercased() {
        case "1", "true", "yes":
            return true
        default:
            return false
        }
    }
}
