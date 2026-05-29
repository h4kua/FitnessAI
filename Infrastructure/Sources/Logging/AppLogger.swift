import Foundation

public struct AppLogger: Sendable {
    private let category: String
    private let subsystem: String

    public init(
        category: String,
        subsystem: String = Bundle.main.bundleIdentifier ?? "com.example.fitnesscoach"
    ) {
        self.category = category
        self.subsystem = subsystem
    }

    public func error(_ message: String) {
        log(level: "ERROR", message: message)
    }

    public func warning(_ message: String) {
        log(level: "WARNING", message: message)
    }

    public func info(_ message: String) {
        log(level: "INFO", message: message)
    }

    private func log(level: String, message: String) {
        NSLog("[%@][%@][%@] %@", subsystem, category, level, message)
    }
}
