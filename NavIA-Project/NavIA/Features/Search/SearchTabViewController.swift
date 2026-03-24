//
//  SearchTabViewController.swift
//  NavIA
//

import UIKit

final class SearchTabViewController: UIViewController {
    private let container = AppContainer.shared

    private weak var titleLabel: UILabel?
    private weak var queryTextField: UITextField?
    private weak var resultsButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel = view.descendants(of: UILabel.self).first
        queryTextField = view.descendants(of: UITextField.self).first
        resultsButton = view.descendants(of: UIButton.self).first

        queryTextField?.keyboardType = .default
        queryTextField?.autocapitalizationType = .words
        queryTextField?.text = container.tripPlannerStore.snapshot.searchQuery.isEmpty
            ? "Sydney"
            : container.tripPlannerStore.snapshot.searchQuery

        resultsButton?.addTarget(self, action: #selector(viewResultsTapped), for: .touchUpInside)
        applyLayout()
    }

    @objc private func viewResultsTapped() {
        let query = queryTextField?.text ?? ""
        let userID = container.sessionStore.currentSession?.user.userID

        container.tripPlannerStore.prepareSearchResults(for: query, userID: userID)

        guard let navigationController = AppNavigator.makeTripFlowNavigationController() else {
            presentSimpleAlert(title: "Navigation Error", message: "Trip flow could not be opened.")
            return
        }

        present(navigationController, animated: true)
    }

    private func applyLayout() {
        guard
            let titleLabel,
            let queryTextField,
            let resultsButton
        else {
            return
        }

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        queryTextField.constrainHeight(to: 44)
        resultsButton.configuration = .filled()
        resultsButton.configuration?.title = "View Results"
        resultsButton.setTitle("View Results", for: .normal)
        resultsButton.constrainHeight(to: 50)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [titleLabel, queryTextField, resultsButton],
            topPadding: 40,
            horizontalPadding: 24,
            bottomPadding: 24,
            spacing: 20
        )

        stackView.setCustomSpacing(32, after: titleLabel)
    }
}
