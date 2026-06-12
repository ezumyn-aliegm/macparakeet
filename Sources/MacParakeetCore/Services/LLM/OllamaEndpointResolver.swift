import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Resolves Ollama endpoints for LAN-hosted Ollama deployments.
/// Ollama is only used when on a configured home LAN prefix; there is no localhost fallback.
public enum OllamaEndpointResolver {
    /// Placeholder host when `OLLAMA_DEFAULT_HOST` is unset (override in Settings or env).
    public static let exampleDefaultHost = "192.168.1.100"
    public static let defaultPort = 11434
    public static let defaultLANPrefix = "192.168.1."

    /// Preferred Ollama OpenAI-compatible base URL.
    /// Honors `OLLAMA_HOST` when set; otherwise uses `OLLAMA_DEFAULT_HOST` or `exampleDefaultHost`.
    public static func preferredBaseURL() -> String {
        if let override = environmentOverride() {
            return override
        }
        return "http://\(defaultHost()):\(defaultPort)/v1"
    }

    /// Whether this machine currently has a home-LAN IPv4 address.
    public static func isOnHomeLAN() -> Bool {
        let prefix = homeLANPrefix()
        return localIPv4Addresses().contains { $0.hasPrefix(prefix) }
    }

    /// Ollama should only be attempted when on the home LAN (or when explicitly overridden).
    public static func isAvailable() -> Bool {
        environmentOverride() != nil || isOnHomeLAN()
    }

    public static func environmentOverride() -> String? {
        guard let raw = trimmedEnvironmentValue("OLLAMA_HOST"), !raw.isEmpty else {
            return nil
        }
        return normalizeBaseURL(raw)
    }

    public static func defaultHost() -> String {
        trimmedEnvironmentValue("OLLAMA_DEFAULT_HOST") ?? exampleDefaultHost
    }

    public static func homeLANPrefix() -> String {
        trimmedEnvironmentValue("OLLAMA_LAN_PREFIX") ?? defaultLANPrefix
    }

    public static func normalizeBaseURL(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        if value.hasSuffix("/v1") {
            return value
        }
        return value + "/v1"
    }

    // MARK: - Private

    private static func trimmedEnvironmentValue(_ key: String) -> String? {
        guard let raw = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return nil
        }
        return raw
    }

    private static func localIPv4Addresses() -> [String] {
        var addresses: [String] = []
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let firstAddress = ifaddrPointer else {
            return addresses
        }
        defer { freeifaddrs(ifaddrPointer) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let interface = pointer?.pointee {
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    interface.ifa_addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    let address = String(cString: hostname)
                    if !address.hasPrefix("127.") {
                        addresses.append(address)
                    }
                }
            }
            pointer = interface.ifa_next
        }
        return addresses
    }
}