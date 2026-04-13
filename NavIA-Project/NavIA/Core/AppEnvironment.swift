//
//  AppEnvironment.swift
//  NavIA
//


import Foundation

enum AppEnvironment {
    private static let fallbackAPIBaseURL = "https://comp208.onrender.com"

    static var apiBaseURL: URL {
        if
            let configuredValue = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            !configuredValue.isEmpty,
            let configuredURL = normalizedBaseURL(from: configuredValue)
        {
            return configuredURL
        }

        guard let fallbackURL = normalizedBaseURL(from: fallbackAPIBaseURL) else {
            preconditionFailure("Invalid fallback API base URL.")
        }

        return fallbackURL
    }

    private static func normalizedBaseURL(from rawValue: String) -> URL? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedValue.isEmpty,
            var components = URLComponents(string: trimmedValue)
        else {
            return nil
        }

        if components.path.hasSuffix("/docs") {
            components.path.removeLast("/docs".count)
        }

        if components.path == "/" {
            components.path = ""
        }

        return components.url
    }
}
