//
//  TripSummaryViewController.swift
//  NavIA
//

import UIKit

final class TripSummaryViewController: UIViewController {
    private let container = AppContainer.shared

    private weak var titleLabel: UILabel?
    private weak var visitedStopsLabel: UILabel?
    private weak var totalTimeLabel: UILabel?
    private weak var distanceLabel: UILabel?
    private weak var backButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()

        let labels = view.descendants(of: UILabel.self)
        titleLabel = labels.first
        visitedStopsLabel = labels.dropFirst().first
        totalTimeLabel = labels.dropFirst(2).first
        distanceLabel = labels.dropFirst(3).first
        backButton = view.descendants(of: UIButton.self).first

        backButton?.addTarget(self, action: #selector(backToHomeTapped), for: .touchUpInside)
        applyLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    private func render() {
        let state = container.makeRoutePlannerViewModel().state

        visitedStopsLabel?.text = "Visited Stops: \(max(state.optimizedPlaces.count - 1, 0))"
        totalTimeLabel?.text = state.timeText
        distanceLabel?.text = state.distanceText
    }

    @objc private func backToHomeTapped() {
        let presentingTabBarController = navigationController?.presentingViewController?.tabBarController

        dismiss(animated: true) {
            presentingTabBarController?.selectedIndex = 0
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
        backButton.configuration = .filled()
        backButton.configuration?.title = "Back to Home"
        backButton.setTitle("Back to Home", for: .normal)
        backButton.constrainHeight(to: 50)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [titleLabel, visitedStopsLabel, totalTimeLabel, distanceLabel, backButton],
            topPadding: 28,
            horizontalPadding: 24,
            bottomPadding: 24,
            spacing: 18
        )

        stackView.setCustomSpacing(24, after: titleLabel)
    }
}
