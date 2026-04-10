//
//  TripSummaryViewController.swift
//  NavIA
//

import UIKit

final class TripSummaryViewController: UIViewController {
    private let container = AppContainer.shared
    private let summaryLabel = UILabel()
    private let routeBreakdownLabel = UILabel()

    private weak var titleLabel: UILabel?
    private weak var visitedStopsLabel: UILabel?
    private weak var totalTimeLabel: UILabel?
    private weak var distanceLabel: UILabel?
    private weak var backButton: UIButton?

    private var isLoadingHistory = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let labels = view.descendants(of: UILabel.self)
        titleLabel = labels.first
        visitedStopsLabel = labels.dropFirst().first
        totalTimeLabel = labels.dropFirst(2).first
        distanceLabel = labels.dropFirst(3).first
        backButton = view.descendants(of: UIButton.self).first

        configureSummaryLabels()
        backButton?.addTarget(self, action: #selector(backToHomeTapped), for: .touchUpInside)
        applyLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadTripHistoryIfNeeded()
        render()
    }

    private func render() {
        let state = container.makeRoutePlannerViewModel().state
        let snapshot = container.tripPlannerStore.snapshot
        let orderedPlaces = orderedPlaces(for: state)
        let orderedPlaceNames = orderedPlaces.map(\.name)
        let droppedPlaceNames = droppedPlaceNames(for: state)
        let attractionStopCount = orderedPlaces.filter { !$0.isCurrentLocationOrigin }.count

        titleLabel?.text = "Trip Summary"
        totalTimeLabel?.text = state.timeText
        distanceLabel?.text = state.distanceText

        if let latestTripHistory = snapshot.latestTripHistory {
            let visitedPlaces = latestTripHistory.places
                .filter { !$0.isCurrentLocationOrigin }
                .filter { !($0.dropped ?? false) }
                .sorted { ($0.visitOrder ?? .max) < ($1.visitOrder ?? .max) }
            let droppedPlaces = latestTripHistory.places
                .filter { !$0.isCurrentLocationOrigin }
                .filter { $0.dropped ?? false }
                .compactMap(\.name)

            visitedStopsLabel?.text = "Visited Stops: \(visitedPlaces.count)"
            summaryLabel.text = [
                "Destination: \(latestTripHistory.displayTitle)",
                "Trip ID: \(latestTripHistory.tripID)",
                "Saved stops: \(visitedPlaces.count)",
                "Dropped stops: \(droppedPlaces.isEmpty ? "None" : droppedPlaces.joined(separator: ", "))"
            ].joined(separator: "\n")

            routeBreakdownLabel.text = visitedPlaces.isEmpty
                ? "The trip was saved, but no ordered stop details were returned."
                : visitedPlaces.map { place in
                    let placeName = place.name ?? place.placeID
                    let arrival = place.arrivalTime ?? "-"
                    let waitMinutes = place.waitTime ?? 0
                    return "Stop \((place.visitOrder ?? 0) + 1): \(placeName) • Arrival: \(arrival) • Wait: \(waitMinutes) min"
                }.joined(separator: "\n")
            return
        }

        visitedStopsLabel?.text = "Visited Stops: \(attractionStopCount)"
        summaryLabel.text = [
            "Destination: \(snapshot.tripInfo.title)",
            "Trip ID: \(snapshot.tripInfo.tripID)",
            "Optimised route: \(orderedPlaceNames.isEmpty ? "-" : orderedPlaceNames.joined(separator: " -> "))",
            "Dropped places: \(droppedPlaceNames.isEmpty ? "None" : droppedPlaceNames.joined(separator: ", "))"
        ].joined(separator: "\n")

        routeBreakdownLabel.text = [
            "Selected stops: \(snapshot.selectedPlaces.map(\.name).joined(separator: ", "))",
            "Polyline segments: \(state.polylines.count)"
        ].joined(separator: "\n")
    }

    @objc private func backToHomeTapped() {
        let hostTabBarController =
            navigationController?.presentingViewController?.tabBarController
            ?? (navigationController?.presentingViewController as? UITabBarController)
            ?? tabBarController

        if let navigationController, navigationController.presentingViewController != nil {
            navigationController.dismiss(animated: true) {
                hostTabBarController?.selectedIndex = 0
            }
            return
        }

        hostTabBarController?.selectedIndex = 0
        navigationController?.popToRootViewController(animated: true)
    }

    private func orderedPlaceNames(for state: RoutePlannerViewModel.ViewState) -> [String] {
        orderedPlaces(for: state).map(\.name)
    }

    private func orderedPlaces(for state: RoutePlannerViewModel.ViewState) -> [Place] {
        let snapshot = container.tripPlannerStore.snapshot
        let indexedPlaces = Dictionary(uniqueKeysWithValues: snapshot.routingPlaces.map { ($0.placeID, $0) })
        return state.optimizedPlaces.compactMap { indexedPlaces[$0] }
    }

    private func droppedPlaceNames(for state: RoutePlannerViewModel.ViewState) -> [String] {
        let snapshot = container.tripPlannerStore.snapshot
        let indexedPlaces = Dictionary(uniqueKeysWithValues: snapshot.routingPlaces.map { ($0.placeID, $0.name) })
        return state.droppedPlaces.compactMap { indexedPlaces[$0] }
    }

    private func loadTripHistoryIfNeeded() {
        let snapshot = container.tripPlannerStore.snapshot

        guard
            snapshot.latestTripHistory == nil,
            !isLoadingHistory,
            let tripID = snapshot.latestOptimizedTripID
        else {
            return
        }

        isLoadingHistory = true
        routeBreakdownLabel.text = "Loading saved trip details..."

        container.tripHistoryService.fetchTripHistory(tripID: tripID) { [weak self] result in
            guard let self else { return }

            self.isLoadingHistory = false

            switch result {
            case .success(let tripHistory):
                self.container.tripPlannerStore.storeTripHistory(tripHistory)
                self.render()

            case .failure:
                self.render()
            }
        }
    }

    private func applyLayout() {
        guard
            let titleLabel,
            let visitedStopsLabel,
            let totalTimeLabel,
            let distanceLabel,
            let backButton
        else {
            return
        }

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        visitedStopsLabel.numberOfLines = 0
        totalTimeLabel.numberOfLines = 0
        distanceLabel.numberOfLines = 0
        summaryLabel.constrainMinimumHeight(to: 110)
        routeBreakdownLabel.constrainMinimumHeight(to: 120)
        backButton.configuration = .filled()
        backButton.configuration?.title = "Back to Home"
        backButton.setTitle("Back to Home", for: .normal)
        backButton.constrainHeight(to: 50)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [titleLabel, visitedStopsLabel, totalTimeLabel, distanceLabel, summaryLabel, routeBreakdownLabel, backButton],
            topPadding: 28,
            horizontalPadding: 24,
            bottomPadding: 24,
            spacing: 18
        )

        stackView.setCustomSpacing(24, after: titleLabel)
    }

    private func configureSummaryLabels() {
        summaryLabel.numberOfLines = 0
        summaryLabel.font = .systemFont(ofSize: 14)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false

        routeBreakdownLabel.numberOfLines = 0
        routeBreakdownLabel.font = .systemFont(ofSize: 14)
        routeBreakdownLabel.textColor = .secondaryLabel
        routeBreakdownLabel.translatesAutoresizingMaskIntoConstraints = false
    }
}
