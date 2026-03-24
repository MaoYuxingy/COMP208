//
//  AppEnvironment.swift
//  NavIA
//


import Foundation

enum AppEnvironment {
    private static let fallbackAPIBaseURL = "http://127.0.0.1:8000"

    static var apiBaseURL: URL {
        if
            let configuredValue = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let configuredURL = URL(string: configuredValue),
            !configuredValue.isEmpty
        {
            return configuredURL
        }

        guard let fallbackURL = URL(string: fallbackAPIBaseURL) else {
            preconditionFailure("Invalid fallback API base URL.")
        }

        return fallbackURL
    }
}
