import Foundation

enum AppleScriptError: LocalizedError {
    case invalidSource
    case executionFailed(message: String, code: Int?)

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            "The AppleScript could not be compiled."
        case let .executionFailed(message, code):
            code.map { "\(message) (\($0))" } ?? message
        }
    }
}

/// Serializes AppleScript execution off the main thread; NSAppleScript is not safe for concurrent use.
actor AppleScriptRunner {
    static let shared = AppleScriptRunner()

    /// Runs `source` and returns the result as a list of strings; `nil` marks an item with no string value.
    func run(_ source: String) throws -> [String?] {
        let result = try execute(source)
        guard result.numberOfItems > 0 else {
            return result.descriptorType == typeNull ? [] : [result.stringValue]
        }
        return (1...result.numberOfItems).map { result.atIndex($0)?.stringValue }
    }

    /// Runs `source` and returns its raw data result; `nil` when the script returns `missing value`.
    func runReturningData(_ source: String) throws -> Data? {
        let result = try execute(source)
        // `missing value` arrives as a type descriptor rather than data.
        return result.descriptorType == typeType || result.descriptorType == typeNull ? nil : result.data
    }

    private func execute(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptError.invalidSource
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            throw AppleScriptError.executionFailed(
                message: errorInfo[NSAppleScript.errorMessage] as? String ?? "AppleScript failed without a message.",
                code: errorInfo[NSAppleScript.errorNumber] as? Int
            )
        }
        return result
    }
}
