//
//  AuthModels.swift
//  NavIA
//

import Foundation

struct AuthUser: Codable, Equatable {
    let userID: String
    let email: String
    let displayName: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case displayName = "display_name"
        case createdAt = "created_at"
        case name
    }

    init(
        userID: String,
        email: String,
        displayName: String?,
        createdAt: Date? = nil
    ) {
        self.userID = userID
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(String.self, forKey: .userID)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userID, forKey: .userID)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct SignUpRequest: Codable, Equatable {
    let email: String
    let password: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case displayName = "display_name"
    }
}

struct SignInRequest: Codable, Equatable {
    let email: String
    let password: String
}

struct AuthResponse: Decodable, Equatable {
    let sessionToken: String
    let tokenType: String?
    let expiresInSeconds: Int?
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresInSeconds = "expires_in_seconds"
        case user
        case userID = "user_id"
        case email
        case displayName = "display_name"
        case createdAt = "created_at"
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sessionToken = try container.decodeIfPresent(String.self, forKey: .sessionToken)
            ?? container.decode(String.self, forKey: .accessToken)
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType)
        expiresInSeconds = try container.decodeIfPresent(Int.self, forKey: .expiresInSeconds)

        if let nestedUser = try container.decodeIfPresent(AuthUser.self, forKey: .user) {
            user = nestedUser
            return
        }

        user = AuthUser(
            userID: try container.decode(String.self, forKey: .userID),
            email: try container.decode(String.self, forKey: .email),
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName)
                ?? container.decodeIfPresent(String.self, forKey: .name),
            createdAt: try container.decodeIfPresent(Date.self, forKey: .createdAt)
        )
    }
}
