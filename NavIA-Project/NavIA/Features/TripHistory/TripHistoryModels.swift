//
//  TripHistoryModels.swift
//  NavIA
//

import Foundation

struct TripHistoryInfo: Decodable, Equatable {
    let tripID: String
    let userID: String?
    let title: String?
    let startTime: Int?
    let totalAvailableTime: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case tripID = "trip_id"
        case userID = "user_id"
        case title
        case startTime = "start_time"
        case totalAvailableTime = "total_available_time"
        case createdAt = "created_at"
    }
}

struct TripHistoryPlace: Decodable, Equatable {
    let id: Int?
    let placeID: String
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let visitDurationMinutes: Int?
    let openTime: Int?
    let closeTime: Int?
    let visitOrder: Int?
    let arrivalTime: String?
    let waitTime: Int?
    let departureTime: String?
    let dropped: Bool?
    let tripID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case placeID = "place_id"
        case name
        case latitude
        case longitude
        case visitDurationMinutes = "visit_duration_minutes"
        case openTime = "open_time"
        case closeTime = "close_time"
        case visitOrder = "visit_order"
        case arrivalTime = "arrival_time"
        case waitTime = "wait_time"
        case departureTime = "departure_time"
        case dropped
        case tripID = "trip_id"
    }
}

struct TripHistoryRecord: Decodable, Equatable {
    let tripInfo: TripHistoryInfo
    let places: [TripHistoryPlace]

    enum CodingKeys: String, CodingKey {
        case tripInfo = "trip_info"
        case places
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        places = try container.decodeIfPresent([TripHistoryPlace].self, forKey: .places) ?? []

        if let nestedTripInfo = try container.decodeIfPresent(TripHistoryInfo.self, forKey: .tripInfo) {
            tripInfo = nestedTripInfo
        } else {
            let legacyInfo = try TripHistoryInfo(from: decoder)
            tripInfo = legacyInfo
        }
    }

    var id: Int? { nil }
    var tripID: String { tripInfo.tripID }
    var userID: String? { tripInfo.userID }
    var title: String? { tripInfo.title }
    var startTime: Int? { tripInfo.startTime }
    var totalAvailableTime: Int? { tripInfo.totalAvailableTime }
    var createdAt: Date? { tripInfo.createdAt }

    var displayTitle: String {
        guard let title, !title.isEmpty else {
            return "Trip \(tripID.prefix(8))"
        }

        return title
    }
}

struct TripHistorySummary: Decodable, Equatable {
    let tripID: String
    let userID: String?
    let title: String?
    let totalAvailableTime: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case tripID = "trip_id"
        case userID = "user_id"
        case title
        case totalAvailableTime = "total_available_time"
        case createdAt = "created_at"
    }
}

struct TripHistoryListResponse: Decodable, Equatable {
    let trips: [TripHistorySummary]
}
