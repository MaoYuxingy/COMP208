//
//  RoutePlannerViewModel.swift
//  NavIA
//


import Foundation

final class RoutePlannerViewModel {
    struct ViewState {
        var isLoading = false
        var selectedPlacesCount = 0
        var statusText = "Status: Add at least 2 places"
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

    private(set) var state = ViewState() {
        didSet { onStateChange?(state) }
    }

    init(
        routeService: RouteOptimizing,
        store: TripPlannerStore = TripPlannerStore()
    ) {
        self.routeService = routeService
        self.store = store

        bindStore()
        updateState(for: store.snapshot)
    }

    func loadSampleDataIfNeeded(userID: String? = nil) {
        store.loadSampleDataIfNeeded(userID: userID)
    }

    func optimizeRoute() {
        do {
            let request = try store.makeRouteRequest()

            state.isLoading = true
            state.statusText = "Status: Loading..."
            state.errorMessage = nil

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

        if let latestRoute = snapshot.latestRoute, !state.isLoading {
            apply(response: latestRoute)
            return
        }

        guard !state.isLoading else {
            return
        }

        state.distanceText = "Distance: -"
        state.timeText = "Time: -"
        state.optimizedPlaces = []
        state.droppedPlaces = []
        state.polylines = []
        state.statusText = snapshot.canOptimize
            ? "Status: Ready to optimize"
            : "Status: Add at least 2 places"
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
        state.distanceText = "Distance: -"
        state.timeText = "Time: -"
        state.optimizedPlaces = []
        state.droppedPlaces = []
        state.polylines = []
        state.errorMessage = error.localizedDescription
    }

    private func apply(response: RouteResponse) {
        state.statusText = "Status: \(response.status)"
        state.distanceText = "Distance: \(response.totalDistanceKm.formatted(.number.precision(.fractionLength(2)))) km"
        state.timeText = "Time: \(response.totalTimeMinutes) min"
        state.optimizedPlaces = response.optimizedOrder
        state.droppedPlaces = response.droppedPlaces
        state.polylines = response.polylines
        state.errorMessage = nil
    }
}
