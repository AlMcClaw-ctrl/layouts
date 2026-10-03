import ApplicationServices

enum AXPermission {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Zeigt den System-Dialog „Bedienungshilfen“, falls noch nicht erlaubt.
    @discardableResult
    static func request() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" // = kAXTrustedCheckOptionPrompt (Swift 6: nicht concurrency-safe)
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
