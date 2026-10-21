import Foundation

/// Strips secrets from diagnostic text before it is stored or shown.
/// Logs never leave this Mac — this is an extra safety net for accidental key leakage in API bodies.
enum SecretRedactor {
    private static let patterns: [(NSRegularExpression, String)] = {
        let raw: [(String, String)] = [
            (#"(?i)(authorization\s*[:=]\s*Bearer\s+)\S+"#, "$1[REDACTED]"),
            (#"(?i)(authorization\s*[:=]\s*token\s+)\S+"#, "$1[REDACTED]"),
            (#"(?i)(Bearer\s+)[A-Za-z0-9\-._~+/]+=*"#, "$1[REDACTED]"),
            (#"(?i)((?:api[_-]?key|access[_-]?token|refresh[_-]?token|oauth[_-]?token|client[_-]?secret)\s*[:=]\s*)\S+"#, "$1[REDACTED]"),
            (#"(?i)(\"?(?:api[_-]?key|access[_-]?token|refresh[_-]?token|token|key|secret)\"?\s*:\s*\")([^\"]+)\""#, "$1[REDACTED]\""),
            (#"\bsk-[A-Za-z0-9_\-]{10,}\b"#, "[REDACTED_KEY]"),
            (#"\bghp_[A-Za-z0-9]{20,}\b"#, "[REDACTED_TOKEN]"),
            (#"\bgithub_pat_[A-Za-z0-9_]{20,}\b"#, "[REDACTED_TOKEN]"),
            (#"\beyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\b"#, "[REDACTED_JWT]")
        ]
        return raw.compactMap { pattern, template in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (regex, template)
        }
    }()

    static func redact(_ text: String) -> String {
        var result = text
        let range = { (s: String) in NSRange(s.startIndex..<s.endIndex, in: s) }
        for (regex, template) in patterns {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range(result),
                withTemplate: template
            )
        }
        // Truncate very long payloads
        if result.count > 4_000 {
            result = String(result.prefix(4_000)) + "\n…[truncated]"
        }
        return result
    }
}
