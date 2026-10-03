import ApplicationServices

enum AXPermission {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system Accessibility prompt if access is not granted yet.
    @discardableResult
    static func request() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" // = kAXTrustedCheckOptionPrompt (Swift 6: not concurrency-safe)
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
