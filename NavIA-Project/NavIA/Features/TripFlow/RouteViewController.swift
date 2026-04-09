//
//  RouteViewController.swift
//  NavIA
//

import MapKit
import UIKit

final class RouteViewController: UIViewController {
    private final class RouteStopAnnotation: NSObject, MKAnnotation {
        let coordinate: CLLocationCoordinate2D
        let title: String?
        let subtitle: String?
        let markerText: String

        init(coordinate: CLLocationCoordinate2D, title: String, subtitle: String?, markerText: String) {
            self.coordinate = coordinate
            self.title = title
            self.subtitle = subtitle
            self.markerText = markerText
        }
    }

    private let container = AppContainer.shared
    private let contentTextView = UITextView()
    private let mapView = MKMapView()
    private let mapPlaceholderLabel = UILabel()
    private let activityIndicatorView = UIActivityIndicatorView(style: .medium)

    private weak var titleLabel: UILabel?
    private weak var contentContainerView: UIView?
    private weak var startNavigationButton: UIButton?
    private weak var displayModeControl: UISegmentedControl?

    private var didAttemptOptimization = false
    private var lastPresentedErrorMessage: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel = view.descendants(of: UILabel.self).first
        startNavigationButton = view.descendants(of: UIButton.self).first
        displayModeControl = view.descendants(of: UISegmentedControl.self).first
        contentContainerView = view.subviews.first(where: { type(of: $0) == UIView.self })

        configureContentView()
        configureActions()
        bindViewModel()
        installCloseButtonIfNeeded()
        applyLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let userID = container.sessionStore.currentSession?.user.userID
        container.makeRoutePlannerViewModel().loadSampleDataIfNeeded(userID: userID)

        if container.tripPlannerStore.snapshot.latestRoute == nil, !didAttemptOptimization {
            didAttemptOptimization = true
            container.makeRoutePlannerViewModel().optimizeRoute()
        } else {
            render(container.makeRoutePlannerViewModel().state)
        }
    }

    private func configureContentView() {
        guard let contentContainerView else {
            return
        }

        titleLabel?.text = "Route"
        contentContainerView.layer.cornerRadius = 18
        contentContainerView.backgroundColor = UIColor.secondarySystemBackground

        contentTextView.isEditable = false
        contentTextView.backgroundColor = .clear
        contentTextView.font = .systemFont(ofSize: 14)
        contentTextView.translatesAutoresizingMaskIntoConstraints = false

        mapView.delegate = self
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.isHidden = true

        mapPlaceholderLabel.font = .systemFont(ofSize: 14)
        mapPlaceholderLabel.textColor = .secondaryLabel
        mapPlaceholderLabel.textAlignment = .center
        mapPlaceholderLabel.numberOfLines = 0
        mapPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        mapPlaceholderLabel.isHidden = true

        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        contentContainerView.addSubview(contentTextView)
        contentContainerView.addSubview(mapView)
        contentContainerView.addSubview(mapPlaceholderLabel)
        contentContainerView.addSubview(activityIndicatorView)

        NSLayoutConstraint.activate([
            contentTextView.topAnchor.constraint(equalTo: contentContainerView.topAnchor, constant: 12),
            contentTextView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 12),
            contentTextView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -12),
            contentTextView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor, constant: -12),

            mapView.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor),

            mapPlaceholderLabel.centerXAnchor.constraint(equalTo: contentContainerView.centerXAnchor),
            mapPlaceholderLabel.centerYAnchor.constraint(equalTo: contentContainerView.centerYAnchor),
            mapPlaceholderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentContainerView.leadingAnchor, constant: 20),
            mapPlaceholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentContainerView.trailingAnchor, constant: -20),

            activityIndicatorView.centerXAnchor.constraint(equalTo: contentContainerView.centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: contentContainerView.centerYAnchor)
        ])
    }

    private func configureActions() {
        displayModeControl?.addTarget(self, action: #selector(displayModeChanged), for: .valueChanged)
        startNavigationButton?.addTarget(self, action: #selector(startNavigationButtonTapped), for: .touchUpInside)
    }

    private func bindViewModel() {
        container.makeRoutePlannerViewModel().onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    private func render(_ state: RoutePlannerViewModel.ViewState) {
        activityIndicatorView.isHidden = !state.isLoading

        if state.isLoading {
            activityIndicatorView.startAnimating()
        } else {
            activityIndicatorView.stopAnimating()
        }

        startNavigationButton?.isEnabled = !state.isLoading && orderedPlaces(for: state).count >= 2
        let navigationTitle = state.isLoading ? "Preparing Route..." : "Start Navigation"
        startNavigationButton?.configuration?.title = navigationTitle
        startNavigationButton?.setTitle(navigationTitle, for: .normal)
        displayModeControl?.setTitle("Summary", forSegmentAt: 0)
        displayModeControl?.setTitle("Map", forSegmentAt: 1)
        updateContent(for: state)
        presentRouteErrorIfNeeded(for: state)
    }

    private func updateContent(for state: RoutePlannerViewModel.ViewState) {
        contentTextView.text = makeSummaryText(for: state)

        updateContentVisibility(for: state)
    }

    private func updateContentVisibility(for state: RoutePlannerViewModel.ViewState) {
        let isMapMode = displayModeControl?.selectedSegmentIndex == 1

        contentTextView.isHidden = isMapMode
        mapView.isHidden = !isMapMode

        guard isMapMode else {
            mapPlaceholderLabel.isHidden = true
            return
        }

        renderMap(for: state)
    }

    private func renderMap(for state: RoutePlannerViewModel.ViewState) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        let orderedPlaces = orderedPlaces(for: state)
        let renderedOverlayCount = addRouteOverlays(for: state, orderedPlaces: orderedPlaces)
        addRouteAnnotations(for: orderedPlaces)

        if state.isLoading {
            mapPlaceholderLabel.isHidden = false
            mapPlaceholderLabel.text = "Generating route map..."
            return
        }

        let hasRenderableMap = renderedOverlayCount > 0 || !mapView.annotations.isEmpty
        mapPlaceholderLabel.isHidden = hasRenderableMap

        if !hasRenderableMap {
            mapPlaceholderLabel.text = state.errorMessage
                ?? "Route map will appear after route optimisation completes."
        }
    }

    @objc private func displayModeChanged() {
        render(container.makeRoutePlannerViewModel().state)
    }

    @objc private func startNavigationButtonTapped() {
        let state = container.makeRoutePlannerViewModel().state
        guard !state.isLoading, orderedPlaces(for: state).count >= 2 else {
            presentSimpleAlert(title: "Route Not Ready", message: "Wait for route optimization to finish before starting navigation.")
            return
        }

        showTripFlowScreen(withIdentifier: "ARNavigationViewController")
    }

    private func applyLayout() {
        guard
            let titleLabel,
            let contentContainerView,
            let startNavigationButton,
            let displayModeControl
        else {
            return
        }

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        contentContainerView.constrainMinimumHeight(to: 320)
        displayModeControl.constrainHeight(to: 32)
        startNavigationButton.configuration = .filled()
        startNavigationButton.configuration?.title = "Start Navigation"
        startNavigationButton.setTitle("Start Navigation", for: .normal)
        startNavigationButton.constrainHeight(to: 50)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [titleLabel, displayModeControl, contentContainerView, startNavigationButton],
            topPadding: 28,
            horizontalPadding: 24,
            bottomPadding: 24,
            spacing: 18
        )

        stackView.setCustomSpacing(24, after: titleLabel)
    }

    private func orderedPlaces(for state: RoutePlannerViewModel.ViewState) -> [Place] {
        let snapshot = container.tripPlannerStore.snapshot
        guard !state.optimizedPlaces.isEmpty else {
            return snapshot.selectedPlaces
        }

        let indexedPlaces = Dictionary(uniqueKeysWithValues: snapshot.selectedPlaces.map { ($0.placeID, $0) })
        return state.optimizedPlaces.compactMap { indexedPlaces[$0] }
    }

    private func makeSummaryText(for state: RoutePlannerViewModel.ViewState) -> String {
        let snapshot = container.tripPlannerStore.snapshot
        let orderedRouteNames = orderedPlaces(for: state).map(\.name)
        let selectedPlaceNames = snapshot.selectedPlaces.map(\.name)
        let droppedPlaceNames = state.droppedPlaces.compactMap { droppedID in
            snapshot.selectedPlaces.first(where: { $0.placeID == droppedID })?.name
        }

        let routeOrderText: String
        if !orderedRouteNames.isEmpty {
            routeOrderText = orderedRouteNames.joined(separator: " -> ")
        } else if !selectedPlaceNames.isEmpty {
            routeOrderText = "Fallback selection order: \(selectedPlaceNames.joined(separator: " -> "))"
        } else {
            routeOrderText = "Waiting for route optimisation."
        }

        let droppedText = droppedPlaceNames.isEmpty
            ? "None"
            : droppedPlaceNames.joined(separator: ", ")
        var sections = [
            "Destination: \(snapshot.tripInfo.title)",
            "Trip ID: \(snapshot.tripInfo.tripID)",
            state.statusText,
            state.distanceText,
            state.timeText,
            "Selected Stops (\(selectedPlaceNames.count)): \(selectedPlaceNames.joined(separator: ", "))",
            "Optimised Route: \(routeOrderText)",
            "Dropped Stops: \(droppedText)",
            "Polyline Segments: \(state.polylines.count)"
        ]

        if let errorMessage = state.errorMessage, !errorMessage.isEmpty {
            sections.append("Route Error: \(errorMessage)")
        }

        return sections.joined(separator: "\n\n")
    }

    private func showTripFlowScreen(withIdentifier storyboardIdentifier: String) {
        let storyboard = UIStoryboard(name: "TripFlow", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: storyboardIdentifier)

        if let navigationController {
            navigationController.pushViewController(controller, animated: true)
            return
        }

        let modalNavigationController = UINavigationController(rootViewController: controller)
        modalNavigationController.modalPresentationStyle = .fullScreen
        present(modalNavigationController, animated: true)
    }

    private func presentRouteErrorIfNeeded(for state: RoutePlannerViewModel.ViewState) {
        guard let errorMessage = state.errorMessage, !errorMessage.isEmpty else {
            lastPresentedErrorMessage = nil
            return
        }

        guard errorMessage != lastPresentedErrorMessage else {
            return
        }

        lastPresentedErrorMessage = errorMessage
        presentSimpleAlert(title: "Route Unavailable", message: errorMessage)
    }

    @discardableResult
    private func addRouteOverlays(for state: RoutePlannerViewModel.ViewState, orderedPlaces: [Place]) -> Int {
        var overlays: [MKPolyline] = state.polylines.compactMap { encodedPolyline in
            let coordinates = GooglePolylineDecoder.decode(encodedPolyline)
            guard coordinates.count >= 2 else {
                return nil
            }

            return MKPolyline(coordinates: coordinates, count: coordinates.count)
        }

        if overlays.isEmpty {
            let fallbackCoordinates = orderedPlaces.map(\.coordinate)

            if fallbackCoordinates.count >= 2 {
                overlays = [MKPolyline(coordinates: fallbackCoordinates, count: fallbackCoordinates.count)]
            }
        }

        guard !overlays.isEmpty else {
            return 0
        }

        mapView.addOverlays(overlays)
        fitMapToRoute(overlays: overlays, places: orderedPlaces)
        return overlays.count
    }

    private func addRouteAnnotations(for orderedPlaces: [Place]) {
        guard !orderedPlaces.isEmpty else {
            return
        }

        let lastIndex = orderedPlaces.count - 1
        let shouldSkipReturnMarker = orderedPlaces.count > 1 && orderedPlaces.first?.placeID == orderedPlaces.last?.placeID

        let annotations = orderedPlaces.enumerated().compactMap { index, place -> RouteStopAnnotation? in
            if shouldSkipReturnMarker && index == lastIndex {
                return nil
            }

            let markerText: String
            let subtitle: String?

            if index == 0 {
                markerText = "S"
                subtitle = "Start"
            } else {
                markerText = "\(index)"
                subtitle = "Stop \(index)"
            }

            return RouteStopAnnotation(
                coordinate: place.coordinate,
                title: place.name,
                subtitle: subtitle,
                markerText: markerText
            )
        }

        mapView.addAnnotations(annotations)
    }

    private func fitMapToRoute(overlays: [MKPolyline], places: [Place]) {
        var mapRect = overlays.reduce(MKMapRect.null) { partialResult, overlay in
            partialResult.isNull ? overlay.boundingMapRect : partialResult.union(overlay.boundingMapRect)
        }

        for place in places {
            let point = MKMapPoint(place.coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            mapRect = mapRect.isNull ? pointRect : mapRect.union(pointRect)
        }

        guard !mapRect.isNull else {
            if let firstPlace = places.first {
                let region = MKCoordinateRegion(
                    center: firstPlace.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
                mapView.setRegion(region, animated: false)
            }
            return
        }

        mapView.setVisibleMapRect(
            mapRect,
            edgePadding: UIEdgeInsets(top: 40, left: 30, bottom: 40, right: 30),
            animated: false
        )
    }
}

extension RouteViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }

        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = .systemBlue
        renderer.lineWidth = 5
        renderer.lineJoin = .round
        renderer.lineCap = .round
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let routeAnnotation = annotation as? RouteStopAnnotation else {
            return nil
        }

        let reuseIdentifier = "RouteStopAnnotationView"
        let annotationView = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: routeAnnotation, reuseIdentifier: reuseIdentifier)

        annotationView.annotation = routeAnnotation
        annotationView.canShowCallout = true
        annotationView.markerTintColor = routeAnnotation.markerText == "S" ? .systemGreen : .systemBlue
        annotationView.glyphText = routeAnnotation.markerText
        return annotationView
    }
}
