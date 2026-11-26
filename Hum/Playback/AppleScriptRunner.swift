import Foundation

/// Runs AppleScript on one serial background queue.
///
/// `NSAppleScript` is not thread-safe, so every script (and the compiled-script cache)
/// is confined to `queue`. This keeps polling off the main thread.
final class AppleScriptRunner: @unchecked Sendable {
    enum RunError: Error {
        case notAuthorized
        case failed(code: Int)
        case compileFailed
    }

    static let shared = AppleScriptRunner()
    static let notAuthorizedCode = -1743

    private let queue = DispatchQueue(label: "hum.applescript", qos: .userInitiated)
    /// Compiled scripts keyed by source. Only touched on `queue`.
    private var compiled: [String: NSAppleScript] = [:]

    func string(_ source: String) async throws -> String {
        try await run(source) { $0.stringValue ?? "" }
    }

    func data(_ source: String) async throws -> Data {
        try await run(source) { $0.data }
    }

    @discardableResult
    func execute(_ source: String) async throws -> Bool {
        try await run(source) { _ in true }
    }

    private func run<T: Sendable>(
        _ source: String,
        transform: @escaping @Sendable (NSAppleEventDescriptor) -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: self.runOnQueue(source).map(transform))
            }
        }
    }

    private func runOnQueue(_ source: String) -> Result<NSAppleEventDescriptor, RunError> {
        let script: NSAppleScript
        if let cached = compiled[source] {
            script = cached
        } else {
            guard let fresh = NSAppleScript(source: source) else { return .failure(.compileFailed) }
            compiled[source] = fresh
            script = fresh
        }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            return .failure(code == Self.notAuthorizedCode ? .notAuthorized : .failed(code: code))
        }
        return .success(descriptor)
    }
}
