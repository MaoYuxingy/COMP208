//
//  RoutePlannerViewModel.swift
//  NavIA
//


import Foundation

final class RoutePlannerViewModel {
    struct ViewState {
        var isLoading = false
        var selectedPlacesCount = 0
        var totalDistanceKm: Double?
        var totalTimeMinutes: Int?
        var statusText = "Status: Add at least 1 attraction to start route planning"
        var locationStatusText = "Current device location not available."
        var distanceText = "Distance: -"
        var timeText = "Time: -"
        var optimizedPlaces: [String] = []
        var droppedPlaces: [String] = []
        var polylines: [String] = []
        var errorMessage: String?

        var optimizedPlacesText: String {
            guard !optimizedPlaces.isEmpty else {
                return "Optimized Order: -"
            }

            return "Optimized Order: \(optimizedPlaces.joined(separator: " -> "))"
        }

        var droppedPlacesText: String {
            guard !droppedPlaces.isEmpty else {
                return "Dropped Places: -"
            }

            return "Dropped Places: \(droppedPlaces.joined(separator: ", "))"
        }
    }

    var onStateChange: ((ViewState) -> Void)?

    let store: TripPlannerStore

    private let routeService: RouteOptimizing
    private let locationService: DeviceLocationProviding

    private(set) var state = ViewState() {
        didSet { onStateChange?(state) }
    }

    init(
        routeService: RouteOptimizing,
        locationService: DeviceLocationProviding,
        store: TripPlannerStore = TripPlannerStore()
    ) {
        self.routeService = routeService
        self.locationService = locationService
        self.store = store

        bindStore()
        updateState(for: store.snapshot)
    }

    func loadSampleDataIfNeeded(userID: String? = nil) {
        store.loadSampleDataIfNeeded(userID: userID)
    }

    func optimizeRoute() {
        state.isLoading = true
        state.statusText = "Status: Loading..."
        state.errorMessage = nil

        locationService.requestCurrentLocation { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                switch result {
                case .success(let coordinate):
                    self.store.updateCurrentLocation(coordinate)

                case .failure:
                    self.store.updateCurrentLocation(nil)
                }

                self.continueOptimizing()
            }
        }
    }

    private func continueOptimizing() {
        do {
            let request = try store.makeRouteRequest()

            routeService.optimizeRoute(request: request) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleOptimizationResult(result)
                }
            }
        } catch {
            presentFailure(error)
        }
    }

    private func bindStore() {
        store.onChange = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.updateState(for: snapshot)
            }
        }
    }

    private func updateState(for snapshot: TripPlannerStore.Snapshot) {
        state.selectedPlacesCount = snapshot.selectedPlaces.count
        state.locationStatusText = snapshot.locationStatusText

        if let latestRoute = snapshot.latestRoute, !state.isLoading {
            apply(response: latestRoute)
            return
        }

        guard !state.isLoading else {
            return
        }

        state.totalDistanceKm = nil
        state.totalTimeMinutes = nil
        state.distanceText = "Distance: -"
        state.timeText = "Time: -"
        state.optimizedPlaces = []
        state.droppedPlaces = []
        state.polylines = []
        state.statusText = snapshot.optimizationRequirementText
    }

    private func handleOptimizationResult(_ result: Result<RouteResponse, Error>) {
        state.isLoading = false

        switch result {
        case .success(let response):
            store.storeOptimizedRoute(response)
            apply(response: response)

        case .failure(let error):
            presentFailure(error)
        }
    }

    private func presentFailure(_ error: Error) {
        state.isLoading = false
        state.statusText = "Status: Failed"
        state.totalDistanceKm = nil
        state.totalTimeMinutes = nil
        state.distanceText = "Distance: -"
        state.timeText = "Time: -"
        state.optimizedPlaces = []
        state.droppedPlaces = []
        state.polylines = []
        state.errorMessage = error.localizedDescription
    }

    private func apply(response: RouteResponse) {
        state.statusText = "Status: \(response.status)"
        state.totalDistanceKm = response.totalDistanceKm
        state.totalTimeMinutes = response.totalTimeMinutes
        state.distanceText = "Distance: \(response.totalDistanceKm.formatted(.number.precision(.fractionLength(2)))) km"
        state.timeText = "Time: \(response.totalTimeMinutes) min"
        state.optimizedPlaces = response.optimizedOrder
        state.droppedPlaces = response.droppedPlaces
        state.polylines = response.polylines
        state.errorMessage = nil
    }
}
