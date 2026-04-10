//
//  AccountViewController.swift
//  NavIA
//

import UIKit

final class AccountViewController: UIViewController {
    private let container = AppContainer.shared
    private let detailsLabel = UILabel()
    private let signOutButton = UIButton(type: .system)

    private weak var titleLabel: UILabel?
    private weak var imageView: UIImageView?
    private weak var refreshButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel = view.descendants(of: UILabel.self).first
        imageView = view.descendants(of: UIImageView.self).first
        refreshButton = view.descendants(of: UIButton.self).first

        configureAvatar()
        configureDetailsLabel()
        configureButtons()
        applyLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    private func configureAvatar() {
        imageView?.image = UIImage(systemName: "person.crop.circle.fill")
        imageView?.tintColor = .systemBlue
    }

    private func configureDetailsLabel() {
        detailsLabel.numberOfLines = 0
        detailsLabel.font = .systemFont(ofSize: 14)
        detailsLabel.textColor = .secondaryLabel
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(detailsLabel)

        signOutButton.configuration = .filled()
        signOutButton.configuration?.title = "Sign Out"
        signOutButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(signOutButton)
    }

    private func configureButtons() {
        refreshButton?.configuration?.title = "Refresh History"
        refreshButton?.setTitle("Refresh History", for: .normal)
        refreshButton?.addTarget(self, action: #selector(refreshHistoryTapped), for: .touchUpInside)
        signOutButton.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
    }

    private func render() {
        let snapshot = container.tripPlannerStore.snapshot
        let email = container.sessionStore.currentSession?.user.email ?? "Not signed in"

        titleLabel?.text = "Account"

        if let latestTripHistory = snapshot.latestTripHistory {
            let persistedAttractionCount = latestTripHistory.places.filter { !$0.isCurrentLocationOrigin }.count
            var lines = [
                "Email: \(email)",
                "Latest trip: \(latestTripHistory.displayTitle)",
                "Trip ID: \(latestTripHistory.tripID)",
                "Places saved: \(persistedAttractionCount)"
            ]

            if !snapshot.tripHistorySummaries.isEmpty {
                lines.append("Trips in history: \(snapshot.tripHistorySummaries.count)")
            }

            if let startTime = latestTripHistory.startTime {
                lines.append("Start time: \(startTime) min")
            }

            if let totalAvailableTime = latestTripHistory.totalAvailableTime {
                lines.append("Available time: \(totalAvailableTime) min")
            }

            detailsLabel.text = lines.joined(separator: "\n")
        } else if let latestSummary = snapshot.tripHistorySummaries.first {
            detailsLabel.text = [
                "Email: \(email)",
                "Latest trip: \(latestSummary.title ?? latestSummary.tripID)",
                "Trip ID: \(latestSummary.tripID)",
                "Trips in history: \(snapshot.tripHistorySummaries.count)",
                "Tap Refresh History to load the trip details."
            ].joined(separator: "\n")
        } else if let latestTripID = snapshot.latestOptimizedTripID {
            detailsLabel.text = [
                "Email: \(email)",
                "Latest trip ID: \(latestTripID)",
                "Tap Refresh History to load the latest trip from the backend."
            ].joined(separator: "\n")
        } else {
            detailsLabel.text = [
                "Email: \(email)",
                "No trip history loaded yet.",
                "Optimize a route first, then come back here to refresh history."
            ].joined(separator: "\n")
        }
    }

    @objc private func refreshHistoryTapped() {
        guard let currentUser = container.sessionStore.currentSession?.user else {
            presentSimpleAlert(title: "Not Signed In", message: "Sign in before loading trip history.")
            return
        }

        detailsLabel.text = "Loading trip history for \(currentUser.email)..."

        container.tripHistoryService.fetchTripHistoryList(userID: currentUser.userID) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let tripSummaries):
                self.container.tripPlannerStore.storeTripHistorySummaries(tripSummaries)

                guard let latestTripID = tripSummaries.first?.tripID else {
                    self.detailsLabel.text = [
                        "Email: \(currentUser.email)",
                        "No trip history found for this user yet."
                    ].joined(separator: "\n")
                    return
                }

                self.loadTripHistoryDetail(tripID: latestTripID)

            case .failure(let error):
                if let latestTripID = self.container.tripPlannerStore.snapshot.latestOptimizedTripID {
                    self.loadTripHistoryDetail(tripID: latestTripID)
                } else {
                    self.detailsLabel.text = "Failed to load trip history.\n\(error.localizedDescription)"
                }
            }
        }
    }

    @objc private func signOutTapped() {
        container.sessionStore.clear()
        AppNavigator.replaceRoot(using: view.window?.windowScene)
    }

    private func loadTripHistoryDetail(tripID: String) {
        detailsLabel.text = "Loading latest trip history for \(tripID)..."

        container.tripHistoryService.fetchTripHistory(tripID: tripID) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let tripHistory):
                self.container.tripPlannerStore.storeTripHistory(tripHistory)
                self.render()

            case .failure(let error):
                self.detailsLabel.text = "Failed to load trip history.\n\(error.localizedDescription)"
            }
        }
    }

    private func applyLayout() {
        guard
            let titleLabel,
            let imageView,
            let refreshButton
        else {
            return
        }

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        imageView.constrainHeight(to: 140)
        detailsLabel.constrainMinimumHeight(to: 96)
        refreshButton.configuration = .bordered()
        refreshButton.configuration?.title = "Refresh History"
        refreshButton.setTitle("Refresh History", for: .normal)
        refreshButton.constrainHeight(to: 50)
        signOutButton.constrainHeight(to: 50)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [titleLabel, imageView, detailsLabel, refreshButton, signOutButton],
            topPadding: 28,
            horizontalPadding: 24,
            bottomPadding: 24,
            spacing: 18
        )

        stackView.setCustomSpacing(24, after: titleLabel)
    }
}
