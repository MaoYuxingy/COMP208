//
//  DevelopmentDashboardViewController.swift
//  NavIA
//


import UIKit

final class DevelopmentDashboardViewController: UIViewController {
    private let viewModel: RoutePlannerViewModel

    private let introLabel = UILabel()
    private let placesLabel = UILabel()
    private let statusLabel = UILabel()
    private let distanceLabel = UILabel()
    private let timeLabel = UILabel()
    private let optimizedOrderLabel = UILabel()
    private let droppedPlacesLabel = UILabel()
    private let errorLabel = UILabel()
    private let optimizeButton = UIButton(type: .system)

    init(viewModel: RoutePlannerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        bindViewModel()
        viewModel.loadSampleDataIfNeeded()
    }

    private func configureView() {
        title = "NavIA Dev"
        view.backgroundColor = .systemGroupedBackground

        introLabel.translatesAutoresizingMaskIntoConstraints = false
        introLabel.text = """
        Storyboards can stay empty for now. This fallback screen lets us verify routing logic until UI scenes are wired.
        API Base URL: \(AppEnvironment.apiBaseURL.absoluteString)
        """
        introLabel.numberOfLines = 0
        introLabel.font = .preferredFont(forTextStyle: .body)

        let metricLabels = [
            placesLabel,
            statusLabel,
            distanceLabel,
            timeLabel,
            optimizedOrderLabel,
            droppedPlacesLabel,
            errorLabel
        ]

        metricLabels.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.numberOfLines = 0
            $0.font = .preferredFont(forTextStyle: .body)
        }

        errorLabel.textColor = .systemRed

        optimizeButton.translatesAutoresizingMaskIntoConstraints = false
        optimizeButton.configuration = .filled()
        optimizeButton.addTarget(self, action: #selector(optimizeButtonTapped), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [
            introLabel,
            placesLabel,
            statusLabel,
            distanceLabel,
            timeLabel,
            optimizedOrderLabel,
            droppedPlacesLabel,
            errorLabel,
            optimizeButton
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }

        render(viewModel.state)
    }

    private func render(_ state: RoutePlannerViewModel.ViewState) {
        placesLabel.text = "Selected Places: \(state.selectedPlacesCount)"
        statusLabel.text = state.statusText
        distanceLabel.text = state.distanceText
        timeLabel.text = state.timeText
        optimizedOrderLabel.text = state.optimizedPlacesText
        droppedPlacesLabel.text = state.droppedPlacesText
        errorLabel.text = state.errorMessage
        optimizeButton.configuration?.title = state.isLoading ? "Optimizing..." : "Run Sample Route Optimization"
        optimizeButton.isEnabled = !state.isLoading && state.selectedPlacesCount >= 2
    }

    @objc
    private func optimizeButtonTapped() {
        viewModel.optimizeRoute()
    }
}
