//
//  UserSessionStore.swift
//  NavIA
//

import Foundation

struct AuthSession: Codable, Equatable {
    let sessionToken: String
    let tokenType: String?
    let expiresInSeconds: Int?
    let user: AuthUser

    var authorizationHeaderValue: String {
        let scheme = tokenType.flatMap { tokenType in
            tokenType.isEmpty ? nil : tokenType.capitalized
        } ?? "Bearer"
        return "\(scheme) \(sessionToken)"
    }
}

final class UserSessionStore {
    static let shared = UserSessionStore()

    var onChange: ((AuthSession?) -> Void)?

    private let defaults: UserDefaults
    private let sessionDefaultsKey = "navia.auth.session"

    private(set) var currentSession: AuthSession? {
        didSet { onChange?(currentSession) }
    }

    var isAuthenticated: Bool {
        currentSession != nil
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentSession = Self.loadSession(from: defaults)
    }

    func updateSession(_ session: AuthSession) {
        currentSession = session
        persistSession()
    }

    func clear() {
        currentSession = nil
        defaults.removeObject(forKey: sessionDefaultsKey)
    }

    private func persistSession() {
        guard let currentSession else {
            defaults.removeObject(forKey: sessionDefaultsKey)
            return
        }

        guard let data = try? JSONEncoder().encode(currentSession) else {
            return
        }

        defaults.set(data, forKey: sessionDefaultsKey)
    }

    private static func loadSession(from defaults: UserDefaults) -> AuthSession? {
        guard let data = defaults.data(forKey: "navia.auth.session") else {
            return nil
        }

        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }
}
