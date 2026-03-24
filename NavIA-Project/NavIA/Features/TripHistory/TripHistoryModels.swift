//
//  TripHistoryModels.swift
//  NavIA
//

import Foundation

struct TripHistoryPlace: Decodable, Equatable {
    let placeID: String
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let visitDurationMinutes: Int?
    let tripID: String?

    enum CodingKeys: String, CodingKey {
        case placeID = "place_id"
        case name
        case latitude
        case longitude
        case visitDurationMinutes = "visit_duration_minutes"
        case tripID = "trip_id"
    }
}

struct TripHistoryRecord: Decodable, Equatable {
    let id: Int?
    let tripID: String
    let userID: String?
    let title: String?
    let totalAvailableTime: Int?
    let createdAt: Date?
    let places: [TripHistoryPlace]

    enum CodingKeys: String, CodingKey {
        case id
        case tripID = "trip_id"
        case userID = "user_id"
        case title
        case totalAvailableTime = "total_available_time"
        case createdAt = "created_at"
        case places
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(Int.self, forKey: .id)
        tripID = try container.decode(String.self, forKey: .tripID)
        userID = try container.decodeIfPresent(String.self, forKey: .userID)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        totalAvailableTime = try container.decodeIfPresent(Int.self, forKey: .totalAvailableTime)
        places = try container.decodeIfPresent([TripHistoryPlace].self, forKey: .places) ?? []

        if let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) {
            self.createdAt = createdAt
        } else if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
            fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

            self.createdAt = formatter.date(from: createdAtString)
                ?? fallbackFormatter.date(from: createdAtString)
        } else {
            createdAt = nil
        }
    }

    var displayTitle: String {
        guard let title, !title.isEmpty else {
            return "Trip \(tripID.prefix(8))"
        }

        return title
    }
}
