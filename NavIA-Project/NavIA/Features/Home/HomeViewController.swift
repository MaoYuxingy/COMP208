//
//  HomeViewController.swift
//  NavIA
//

import UIKit

final class HomeViewController: UIViewController {
    private let container = AppContainer.shared
    private let summaryLabel = UILabel()

    private weak var exploreButton: UIButton?
    private weak var summaryContainerView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSummaryView()
        configureButton()
        applyLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    private func configureSummaryView() {
        exploreButton = view.descendants(of: UIButton.self).first
        summaryContainerView = view.subviews.first(where: { type(of: $0) == UIView.self })

        guard let summaryContainerView else {
            return
        }

        summaryLabel.numberOfLines = 0
        summaryLabel.font = .systemFont(ofSize: 14)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false

        summaryContainerView.layer.cornerRadius = 18
        summaryContainerView.backgroundColor = UIColor.secondarySystemBackground
        summaryContainerView.addSubview(summaryLabel)

        NSLayoutConstraint.activate([
            summaryLabel.topAnchor.constraint(equalTo: summaryContainerView.topAnchor, constant: 16),
            summaryLabel.leadingAnchor.constraint(equalTo: summaryContainerView.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: summaryContainerView.trailingAnchor, constant: -16),
            summaryLabel.bottomAnchor.constraint(equalTo: summaryContainerView.bottomAnchor, constant: -16)
        ])
    }

    private func configureButton() {
        exploreButton?.addTarget(self, action: #selector(exploreTapped), for: .touchUpInside)
    }

    private func render() {
        let snapshot = container.tripPlannerStore.snapshot
        let userEmail = container.sessionStore.currentSession?.user.email ?? "Guest"
        let latestTrip = snapshot.latestTripHistory?.displayTitle ?? snapshot.tripInfo.title
        let latestTripID = snapshot.latestOptimizedTripID ?? "No saved trip"
        let locationStatus = snapshot.currentLocationPlace == nil ? "Unavailable" : "Ready"

        summaryLabel.text = [
            "Signed in as: \(userEmail)",
            "Current destination: \(latestTrip)",
            "Selected places: \(snapshot.selectedPlaces.count)",
            "Device location: \(locationStatus)",
            "Latest trip ID: \(latestTripID)"
        ].joined(separator: "\n")
    }

    @objc private func exploreTapped() {
        tabBarController?.selectedIndex = 1
    }

    private func applyLayout() {
        let labels = view.descendants(of: UILabel.self)
        let titleLabel = labels.first

        guard
            let titleLabel,
            let summaryContainerView,
            let exploreButton
        else {
            return
        }

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        summaryContainerView.constrainMinimumHeight(to: 180)
        exploreButton.configuration = .filled()
        exploreButton.configuration?.title = "Explore"
        exploreButton.setTitle("Explore", for: .normal)
        exploreButton.constrainHeight(to: 50)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [titleLabel, summaryContainerView, exploreButton],
            topPadding: 28,
            horizontalPadding: 24,
            bottomPadding: 24,
            spacing: 20
        )

        stackView.setCustomSpacing(28, after: titleLabel)
    }
}
