//
//  APIService.swift
//  NavIA
//
//  Created by 万俟修杰 on 2026/3/6.
//

import Foundation

protocol RouteOptimizing {
    func optimizeRoute(request: RouteRequest, completion: @escaping (Result<RouteResponse, Error>) -> Void)
}

protocol TripHistoryFetching {
    func fetchTripHistory(tripID: String, completion: @escaping (Result<TripHistoryRecord, Error>) -> Void)
    func fetchTripHistoryList(userID: String, completion: @escaping (Result<[TripHistorySummary], Error>) -> Void)
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(statusCode: Int, message: String?)
    case encoding(Error)
    case decoding(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .server(let statusCode, let message):
            if statusCode == 503, let message, message.contains("Google Maps API Key") || message.contains("尚未配置") {
                return "Route optimisation is unavailable because the backend Google Maps API key is not configured. Add GOOGLE_MAPS_API_KEY to NavIA_Backend/.env and restart the backend."
            }

            if statusCode == 403, let message, message.contains("地图服务授权失败") || message.lowercased().contains("api") {
                return "Google Maps rejected the backend request. Check that GOOGLE_MAPS_API_KEY is valid and has the required Maps permissions enabled."
            }

            if let message, !message.isEmpty {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error (\(statusCode))."
        case .encoding:
            return "Failed to encode the request body."
        case .decoding:
            return "Failed to decode the server response."
        case .network(let error):
            return error.localizedDescription
        }
    }
}

struct APIErrorPayload: Decodable {
    let detail: String?
}

final class APIService: RouteOptimizing, TripHistoryFetching {
    static let shared = APIService()

    private let baseURL: URL
    private let session: URLSession
    private let sessionStore: UserSessionStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL = AppEnvironment.apiBaseURL,
        session: URLSession = .shared,
        sessionStore: UserSessionStore = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.sessionStore = sessionStore

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func optimizeRoute(request: RouteRequest, completion: @escaping (Result<RouteResponse, Error>) -> Void) {
        var urlRequest = makeRequest(path: "api/v1/optimize-route", method: "POST")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            completion(.failure(APIError.encoding(error)))
            return
        }

        performRequest(urlRequest, completion: completion)
    }

    func fetchTripHistory(tripID: String, completion: @escaping (Result<TripHistoryRecord, Error>) -> Void) {
        let urlRequest = makeRequest(path: "api/v1/trips/\(tripID)", method: "GET")
        performRequest(urlRequest, completion: completion)
    }

    func fetchTripHistoryList(userID: String, completion: @escaping (Result<[TripHistorySummary], Error>) -> Void) {
        let urlRequest = makeRequest(path: "api/v1/users/\(userID)/trips", method: "GET")

        performRequest(urlRequest) { (result: Result<TripHistoryListResponse, Error>) in
            switch result {
            case .success(let response):
                completion(.success(response.trips))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func makeRequest(path: String, method: String) -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let authorizationHeader = sessionStore.currentSession?.authorizationHeaderValue {
            urlRequest.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        }

        return urlRequest
    }

    private func performRequest<Response: Decodable>(
        _ request: URLRequest,
        completion: @escaping (Result<Response, Error>) -> Void
    ) {
        session.dataTask(with: request) { [decoder] data, response, error in
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
                    let result = try decoder.decode(Response.self, from: data)
                    completion(.success(result))
                } catch {
                    completion(.failure(APIError.decoding(error)))
                }
            }
        }.resume()
    }
}
