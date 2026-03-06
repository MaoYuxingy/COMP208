//
//  RouteModels.swift
//  NavIA
//
//  Created by 万俟修杰 on 2026/3/6.
//
import Foundation

struct TripInfo: Codable {
    let trip_id: String
    let user_id: String
    let title: String
    let total_available_time: Int
    let created_at: String
}

struct Place: Codable {
    let place_id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let cached: Bool
    let visit_duration_minutes: Int
}

struct RouteRequest: Codable {
    let trip_info: TripInfo
    let places_to_visit: [Place]
}

struct RouteResponse: Codable {
    let route_id: String
    let status: String
    let total_distance_km: Double
    let total_time_minutes: Double
    let optimized_order: [String]
    let dropped_places: [String]
}
