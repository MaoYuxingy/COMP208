//
//  PlanningViewController.swift
//  NavIA
//

import UIKit

final class PlanningViewController: UIViewController, UITableViewDataSource {
    private let container = AppContainer.shared

    private weak var titleLabel: UILabel?
    private weak var tableView: UITableView?
    private weak var routeButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel = view.descendants(of: UILabel.self).first
        tableView = view.descendants(of: UITableView.self).first
        routeButton = view.descendants(of: UIButton.self).first

        tableView?.dataSource = self
        routeButton?.addTarget(self, action: #selector(viewRouteTapped), for: .touchUpInside)
        applyLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let userID = container.sessionStore.currentSession?.user.userID
        container.tripPlannerStore.loadSampleDataIfNeeded(userID: userID)
        tableView?.reloadData()
    }

    @objc private func viewRouteTapped() {
        let userID = container.sessionStore.currentSession?.user.userID
        container.tripPlannerStore.loadSampleDataIfNeeded(userID: userID)

        guard container.tripPlannerStore.snapshot.canOptimize else {
            presentSimpleAlert(title: "Trip Not Ready", message: "Add at least two attractions before viewing the route.")
            return
        }

        guard let navigationController = AppNavigator.makeTripFlowNavigationController(startingAt: "RouteViewController") else {
            presentSimpleAlert(title: "Navigation Error", message: "Route screen could not be opened.")
            return
        }

        present(navigationController, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        container.tripPlannerStore.snapshot.selectedPlaces.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "PlanningPlaceCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)

        let place = container.tripPlannerStore.snapshot.selectedPlaces[indexPath.row]
        cell.textLabel?.text = place.name
        cell.detailTextLabel?.text = "Visit \(place.visitDurationMinutes) min • \(place.openTime)-\(place.closeTime)"
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    private func applyLayout() {
        guard
            let titleLabel,
            let tableView,
            let routeButton
        else {
            return
        }

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        tableView.layer.cornerRadius = 18
        tableView.constrainMinimumHeight(to: 280)
        routeButton.configuration = .filled()
        routeButton.configuration?.title = "View Route"
        routeButton.setTitle("View Route", for: .normal)
        routeButton.constrainHeight(to: 50)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [titleLabel, tableView, routeButton],
            topPadding: 28,
            horizontalPadding: 24,
            bottomPadding: 24,
            spacing: 20
        )

        stackView.setCustomSpacing(24, after: titleLabel)
    }
}
