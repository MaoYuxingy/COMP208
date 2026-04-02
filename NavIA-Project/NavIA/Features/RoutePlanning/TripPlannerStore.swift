//
//  TripPlannerStore.swift
//  NavIA

import Foundation

enum TripPlannerStoreError: LocalizedError {
    case insufficientPlaces

    var errorDescription: String? {
        switch self {
        case .insufficientPlaces:
            return "Add at least 2 places before optimizing a route."
        }
    }
}

final class TripPlannerStore {
    struct Snapshot {
        let tripInfo: TripInfo
        let searchQuery: String
        let searchResults: [Place]
        let selectedPlaces: [Place]
        let selectedPlace: Place?
        let latestRoute: RouteResponse?
        let latestOptimizedTripID: String?
        let latestTripHistory: TripHistoryRecord?
        let tripHistorySummaries: [TripHistorySummary]

        var canOptimize: Bool {
            selectedPlaces.count >= 2
        }
    }

    var onChange: ((Snapshot) -> Void)?

    private let defaults: UserDefaults
    private let latestTripDefaultsKey = "navia.latest.trip.id"

    private(set) var tripInfo: TripInfo
    private(set) var searchQuery: String
    private(set) var searchResults: [Place]
    private(set) var selectedPlaces: [Place]
    private(set) var selectedPlaceID: String?
    private(set) var latestRoute: RouteResponse?
    private(set) var latestOptimizedTripID: String?
    private(set) var latestTripHistory: TripHistoryRecord?
    private(set) var tripHistorySummaries: [TripHistorySummary]

    init(
        tripInfo: TripInfo = .sampleLiverpoolTrip,
        selectedPlaces: [Place] = [],
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.tripInfo = tripInfo
        self.searchQuery = tripInfo.title
        self.searchResults = []
        self.selectedPlaces = selectedPlaces
        self.selectedPlaceID = selectedPlaces.first?.placeID
        self.latestRoute = nil
        self.latestOptimizedTripID = defaults.string(forKey: latestTripDefaultsKey)
        self.latestTripHistory = nil
        self.tripHistorySummaries = []
    }

    var snapshot: Snapshot {
        Snapshot(
            tripInfo: tripInfo,
            searchQuery: searchQuery,
            searchResults: searchResults,
            selectedPlaces: selectedPlaces,
            selectedPlace: selectedPlace,
            latestRoute: latestRoute,
            latestOptimizedTripID: latestOptimizedTripID,
            latestTripHistory: latestTripHistory,
            tripHistorySummaries: tripHistorySummaries
        )
    }

    var selectedPlace: Place? {
        if let selectedPlaceID {
            return searchResults.first(where: { $0.placeID == selectedPlaceID })
                ?? selectedPlaces.first(where: { $0.placeID == selectedPlaceID })
        }

        return searchResults.first ?? selectedPlaces.first
    }

    func setTripInfo(_ tripInfo: TripInfo) {
        self.tripInfo = tripInfo
        notifyChange()
    }

    func prepareSearchResults(for query: String, userID: String?) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = normalizedQuery.isEmpty ? "Liverpool" : normalizedQuery
        let generatedPlaces = Place.sampleStops(for: destination)

        searchQuery = destination
        searchResults = generatedPlaces
        selectedPlaces = generatedPlaces
        selectedPlaceID = generatedPlaces.first?.placeID
        latestRoute = nil

        tripInfo = TripInfo(
            tripID: UUID().uuidString,
            userID: userID ?? tripInfo.userID,
            title: destination,
            startTime: tripInfo.startTime,
            totalAvailableTime: tripInfo.totalAvailableTime,
            createdAt: Date()
        )

        notifyChange()
    }

    func replacePlaces(_ places: [Place]) {
        var seenPlaceIDs = Set<String>()
        selectedPlaces = places.filter { seenPlaceIDs.insert($0.placeID).inserted }
        if selectedPlace == nil {
            selectedPlaceID = selectedPlaces.first?.placeID
        }
        latestRoute = nil
        notifyChange()
    }

    func addPlace(_ place: Place) {
        guard !selectedPlaces.contains(where: { $0.placeID == place.placeID }) else {
            return
        }

        selectedPlaces.append(place)
        selectedPlaceID = place.placeID
        latestRoute = nil
        notifyChange()
    }

    func removePlace(withID placeID: String) {
        selectedPlaces.removeAll { $0.placeID == placeID }
        if selectedPlaceID == placeID {
            selectedPlaceID = selectedPlaces.first?.placeID
        }
        latestRoute = nil
        notifyChange()
    }

    func selectPlace(withID placeID: String) {
        guard searchResults.contains(where: { $0.placeID == placeID }) || selectedPlaces.contains(where: { $0.placeID == placeID }) else {
            return
        }

        selectedPlaceID = placeID
        notifyChange()
    }

    func storeOptimizedRoute(_ route: RouteResponse) {
        latestRoute = route
        latestOptimizedTripID = tripInfo.tripID
        defaults.set(tripInfo.tripID, forKey: latestTripDefaultsKey)
        notifyChange()
    }

    func storeTripHistory(_ tripHistory: TripHistoryRecord) {
        latestTripHistory = tripHistory
        latestOptimizedTripID = tripHistory.tripID
        defaults.set(tripHistory.tripID, forKey: latestTripDefaultsKey)
        notifyChange()
    }

    func storeTripHistorySummaries(_ tripHistorySummaries: [TripHistorySummary]) {
        self.tripHistorySummaries = tripHistorySummaries

        if let latestTripID = tripHistorySummaries.first?.tripID {
            latestOptimizedTripID = latestTripID
            defaults.set(latestTripID, forKey: latestTripDefaultsKey)
        }

        notifyChange()
    }

    func loadSampleDataIfNeeded(userID: String?) {
        guard searchResults.isEmpty && selectedPlaces.isEmpty else {
            return
        }

        prepareSearchResults(for: tripInfo.title, userID: userID)
    }

    func makeRouteRequest() throws -> RouteRequest {
        guard snapshot.canOptimize else {
            throw TripPlannerStoreError.insufficientPlaces
        }

        return RouteRequest(
            tripInfo: tripInfo,
            placesToVisit: selectedPlaces
        )
    }

    private func notifyChange() {
        onChange?(snapshot)
    }
}
