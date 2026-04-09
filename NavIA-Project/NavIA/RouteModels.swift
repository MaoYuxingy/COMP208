//
//  RouteModels.swift
//  NavIA
//
//  Created by 万俟修杰 on 2026/3/6.
//
import Foundation
import CoreLocation

struct TripInfo: Codable, Equatable {
    let tripID: String
    let userID: String
    let title: String
    let startTime: Int
    let totalAvailableTime: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case tripID = "trip_id"
        case userID = "user_id"
        case title
        case startTime = "start_time"
        case totalAvailableTime = "total_available_time"
        case createdAt = "created_at"
    }
}

struct Place: Codable, Equatable, Identifiable {
    let placeID: String
    let name: String
    let latitude: Double
    let longitude: Double
    let cached: Bool
    let visitDurationMinutes: Int
    let openTime: Int
    let closeTime: Int

    var id: String { placeID }

    enum CodingKeys: String, CodingKey {
        case placeID = "place_id"
        case name
        case latitude
        case longitude
        case cached
        case visitDurationMinutes = "visit_duration_minutes"
        case openTime = "open_time"
        case closeTime = "close_time"
    }
}

struct RouteRequest: Codable {
    let tripInfo: TripInfo
    let placesToVisit: [Place]

    enum CodingKeys: String, CodingKey {
        case tripInfo = "trip_info"
        case placesToVisit = "places_to_visit"
    }
}

struct RouteResponse: Codable {
    let routeID: String
    let status: String
    let totalDistanceKm: Double
    let totalTimeMinutes: Int
    let optimizedOrder: [String]
    let droppedPlaces: [String]
    let polylines: [String]

    enum CodingKeys: String, CodingKey {
        case routeID = "route_id"
        case status
        case totalDistanceKm = "total_distance_km"
        case totalTimeMinutes = "total_time_minutes"
        case optimizedOrder = "optimized_order"
        case droppedPlaces = "dropped_places"
        case polylines
    }
}

extension TripInfo {
    static var sampleLiverpoolTrip: TripInfo {
        let formatter = ISO8601DateFormatter()
        let createdAt = formatter.date(from: "2026-03-06T11:34:18.764Z") ?? Date()

        return TripInfo(
            tripID: "trip001",
            userID: "user001",
            title: "Liverpool Trip",
            startTime: 540,
            totalAvailableTime: 480,
            createdAt: createdAt
        )
    }
}

extension Place {
    static var sampleLiverpoolStops: [Place] {
        sampleStops(for: "Liverpool")
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func sampleStops(for destination: String) -> [Place] {
        let normalizedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch normalizedDestination {
        case let value where value.contains("sydney"):
            return [
                Place(
                    placeID: "syd-opera-house",
                    name: "Sydney Opera House",
                    latitude: -33.8568,
                    longitude: 151.2153,
                    cached: false,
                    visitDurationMinutes: 90,
                    openTime: 540,
                    closeTime: 1260
                ),
                Place(
                    placeID: "syd-botanic-garden",
                    name: "Royal Botanic Garden",
                    latitude: -33.8642,
                    longitude: 151.2166,
                    cached: false,
                    visitDurationMinutes: 60,
                    openTime: 480,
                    closeTime: 1200
                ),
                Place(
                    placeID: "syd-harbour-bridge",
                    name: "Sydney Harbour Bridge",
                    latitude: -33.8523,
                    longitude: 151.2108,
                    cached: false,
                    visitDurationMinutes: 45,
                    openTime: 540,
                    closeTime: 1260
                )
            ]

        case let value where value.contains("london"):
            return [
                Place(
                    placeID: "ldn-british-museum",
                    name: "British Museum",
                    latitude: 51.5194,
                    longitude: -0.1270,
                    cached: false,
                    visitDurationMinutes: 90,
                    openTime: 600,
                    closeTime: 1020
                ),
                Place(
                    placeID: "ldn-london-eye",
                    name: "London Eye",
                    latitude: 51.5033,
                    longitude: -0.1195,
                    cached: false,
                    visitDurationMinutes: 60,
                    openTime: 660,
                    closeTime: 1260
                ),
                Place(
                    placeID: "ldn-tower-bridge",
                    name: "Tower Bridge",
                    latitude: 51.5055,
                    longitude: -0.0754,
                    cached: false,
                    visitDurationMinutes: 50,
                    openTime: 570,
                    closeTime: 1140
                )
            ]

        default:
            return [
                Place(
                    placeID: "liv-museum",
                    name: "Museum of Liverpool",
                    latitude: 53.406,
                    longitude: -2.996,
                    cached: false,
                    visitDurationMinutes: 60,
                    openTime: 540,
                    closeTime: 1020
                ),
                Place(
                    placeID: "liv-cathedral",
                    name: "Liverpool Cathedral",
                    latitude: 53.397,
                    longitude: -2.971,
                    cached: false,
                    visitDurationMinutes: 45,
                    openTime: 600,
                    closeTime: 1080
                ),
                Place(
                    placeID: "liv-albert-dock",
                    name: "Royal Albert Dock",
                    latitude: 53.4008,
                    longitude: -2.9919,
                    cached: false,
                    visitDurationMinutes: 75,
                    openTime: 570,
                    closeTime: 1140
                )
            ]
        }
    }
}
