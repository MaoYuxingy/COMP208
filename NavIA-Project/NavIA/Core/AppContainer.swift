//
//  AppContainer.swift
//  NavIA
//

import Foundation

final class AppContainer {
    static let shared = AppContainer()

    let apiService: APIService
    let routeService: RouteOptimizing
    let tripHistoryService: TripHistoryFetching
    let locationService: DeviceLocationProviding
    let sessionStore: UserSessionStore
    let tripPlannerStore: TripPlannerStore

    private lazy var routePlannerViewModel = RoutePlannerViewModel(
        routeService: routeService,
        locationService: locationService,
        store: tripPlannerStore
    )

    init(
        apiService: APIService = .shared,
        locationService: DeviceLocationProviding = DeviceLocationService.shared
    ) {
        self.apiService = apiService
        self.routeService = apiService
        self.tripHistoryService = apiService
        self.locationService = locationService
        self.sessionStore = .shared
        self.tripPlannerStore = TripPlannerStore()
    }

    func makeRoutePlannerViewModel() -> RoutePlannerViewModel {
        routePlannerViewModel
    }
}
