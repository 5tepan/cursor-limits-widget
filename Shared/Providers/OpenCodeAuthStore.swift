import Foundation

/// Reads provider API keys from OpenCode's local auth.json — never from the network.
enum OpenCodeAuthStore {
    private static var authFileURLs: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".local/share/opencode/auth.json"),
            home.appendingPathComponent(".config/opencode/auth.json"),
            home.appendingPathComponent(".opencode/auth.json")
        ]
    }

    /// Exact / alias match against top-level map keys and nested provider/id/name fields.
    static func apiKey(matching aliases: [String]) -> String? {
        let normalized = Set(aliases.map { normalize($0) }.filter { !$0.isEmpty })
        guard !normalized.isEmpty else { return nil }

        for url in authFileURLs {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data)
            else { continue }

            if let dict = json as? [String: Any] {
                // Prefer explicit top-level provider buckets: { "ollama-cloud": { "key": "..." } }
                for (key, value) in dict {
                    guard normalized.contains(normalize(key)),
                          let nested = value as? [String: Any],
                          let secret = firstSecret(in: nested)
                    else { continue }
                    return secret
                }
                // Flat / array-style entries with provider field
                if let secret = secretFromEntry(dict, matching: normalized) {
                    return secret
                }
                for value in dict.values {
                    if let nested = value as? [String: Any],
                       let secret = secretFromEntry(nested, matching: normalized)
                    {
                        return secret
                    }
                }
            }

            if let array = json as? [[String: Any]] {
                for item in array {
                    if let secret = secretFromEntry(item, matching: normalized) {
                        return secret
                    }
                }
            }
        }
        return nil
    }

    private static func secretFromEntry(_ dict: [String: Any], matching aliases: Set<String>) -> String? {
        let provider = [
            dict["provider"] as? String,
            dict["id"] as? String,
            dict["name"] as? String,
            dict["type"] as? String
        ]
        .compactMap { $0 }
        .map(normalize)

        guard provider.contains(where: { aliases.contains($0) }) else { return nil }
        return firstSecret(in: dict)
    }

    private static func firstSecret(in dict: [String: Any]) -> String? {
        for key in ["key", "apiKey", "api_key", "token", "accessToken", "access_token"] {
            if let value = dict[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }
}
