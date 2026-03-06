//
//  APIService.swift
//  NavIA
//
//  Created by 万俟修杰 on 2026/3/6.
//

import Foundation

final class APIService {
    
    static let shared = APIService()
    
    private init() {}
    
    private let baseURL = "http://127.0.0.1:8001"
    
    func optimizeRoute(request: RouteRequest, completion: @escaping (Result<RouteResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/v1/optimize-route") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No Data", code: -2)))
                return
            }
            
            do {
                let result = try JSONDecoder().decode(RouteResponse.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
