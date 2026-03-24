//
//  RouteViewController.swift
//  NavIA
//

import UIKit

final class RouteViewController: UIViewController {
    private let container = AppContainer.shared
    private let contentTextView = UITextView()
    private let activityIndicatorView = UIActivityIndicatorView(style: .medium)

    private weak var titleLabel: UILabel?
    private weak var contentContainerView: UIView?
    private weak var startNavigationButton: UIButton?
    private weak var displayModeControl: UISegmentedControl?

    private var didAttemptOptimization = false

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

    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        let state = container.makeRoutePlannerViewModel().state
        guard !state.isLoading, !state.optimizedPlaces.isEmpty else {
            presentSimpleAlert(title: "Route Not Ready", message: "Wait for route optimization to finish before starting navigation.")
            return false
        }

        return true
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

        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        contentContainerView.addSubview(contentTextView)
        contentContainerView.addSubview(activityIndicatorView)

        NSLayoutConstraint.activate([
            contentTextView.topAnchor.constraint(equalTo: contentContainerView.topAnchor, constant: 12),
            contentTextView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 12),
            contentTextView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -12),
            contentTextView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor, constant: -12),

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

        startNavigationButton?.isEnabled = !state.isLoading && !state.optimizedPlaces.isEmpty
        updateContentText(for: state)
    }

    private func updateContentText(for state: RoutePlannerViewModel.ViewState) {
        let isPolylineMode = displayModeControl?.selectedSegmentIndex == 1

        if isPolylineMode {
            let polylineSummary = state.polylines.isEmpty
                ? "No encoded polyline data returned."
                : state.polylines.enumerated().map { index, polyline in
                    "Leg \(index + 1): \(polyline)"
                }.joined(separator: "\n\n")

            contentTextView.text = [
                state.statusText,
                "Polyline count: \(state.polylines.count)",
                polylineSummary
            ].joined(separator: "\n\n")
            return
        }

        contentTextView.text = [
            state.statusText,
            state.distanceText,
            state.timeText,
            state.optimizedPlacesText,
            state.droppedPlacesText
        ].joined(separator: "\n\n")
    }

    @objc private func displayModeChanged() {
        render(container.makeRoutePlannerViewModel().state)
    }

    @objc private func startNavigationButtonTapped() {
        // The storyboard segue handles navigation. This target only ensures state is up to date.
        render(container.makeRoutePlannerViewModel().state)
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
}
