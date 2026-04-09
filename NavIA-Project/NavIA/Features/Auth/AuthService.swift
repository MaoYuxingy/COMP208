//
//  AuthService.swift
//  NavIA
//


import Foundation

protocol Authenticating {
    func signUp(request: SignUpRequest, completion: @escaping (Result<AuthSession, Error>) -> Void)
    func signIn(request: SignInRequest, completion: @escaping (Result<AuthSession, Error>) -> Void)
}

final class AuthService: Authenticating {
    static let shared = AuthService()

    private struct RegisterPayload: Encodable {
        let email: String
        let displayName: String
        let password: String

        enum CodingKeys: String, CodingKey {
            case email
            case displayName = "display_name"
            case password
        }
    }

    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL = AppEnvironment.apiBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func signUp(request: SignUpRequest, completion: @escaping (Result<AuthSession, Error>) -> Void) {
        let trimmedEmail = request.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackDisplayName = trimmedEmail.isEmpty ? "NavIA User" : trimmedEmail
        let resolvedDisplayName = request.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? fallbackDisplayName

        performAuthRequest(
            path: "api/v1/auth/register",
            request: RegisterPayload(
                email: trimmedEmail,
                displayName: resolvedDisplayName,
                password: request.password
            ),
            completion: completion
        )
    }

    func signIn(request: SignInRequest, completion: @escaping (Result<AuthSession, Error>) -> Void) {
        performAuthRequest(
            path: "api/v1/auth/login",
            request: request,
            completion: completion
        )
    }

    private func performAuthRequest<Request: Encodable>(
        path: String,
        request: Request,
        completion: @escaping (Result<AuthSession, Error>) -> Void
    ) {
        let url = baseURL.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            completion(.failure(APIError.encoding(error)))
            return
        }

        session.dataTask(with: urlRequest) { [decoder] data, response, error in
            if let error = error {
                Task { @MainActor in
                    completion(.failure(APIError.network(error)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                Task { @MainActor in
                    completion(.failure(APIError.invalidResponse))
                }
                return
            }

            guard let data = data else {
                Task { @MainActor in
                    completion(.failure(APIError.invalidResponse))
                }
                return
            }

            let statusCode = httpResponse.statusCode
            Task { @MainActor in
                guard (200 ..< 300).contains(statusCode) else {
                    let payload = try? decoder.decode(APIErrorPayload.self, from: data)
                    completion(.failure(APIError.server(statusCode: statusCode, message: payload?.detail)))
                    return
                }

                do {
                    let response = try decoder.decode(AuthResponse.self, from: data)
                    completion(
                        .success(
                            AuthSession(
                                sessionToken: response.sessionToken,
                                tokenType: response.tokenType,
                                expiresInSeconds: response.expiresInSeconds,
                                user: response.user
                            )
                        )
                    )
                } catch {
                    completion(.failure(APIError.decoding(error)))
                }
            }
        }.resume()
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
