//
//  SearchResultsViewController.swift
//  NavIA
//

import UIKit

final class SearchResultsViewController: UIViewController {
    private let store = AppContainer.shared.tripPlannerStore
    private let stackView = UIStackView()

    private weak var titleLabel: UILabel?
    private weak var resultsContainerView: UIView?
    private weak var detailsButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel = view.descendants(of: UILabel.self).first
        detailsButton = view.descendants(of: UIButton.self).first
        resultsContainerView = view.subviews.first(where: { type(of: $0) == UIView.self })

        configureStackView()
        detailsButton?.addTarget(self, action: #selector(prepareSelectedPlaceForSegue), for: .touchUpInside)
        installCloseButtonIfNeeded()
        applyLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    private func configureStackView() {
        guard let resultsContainerView else {
            return
        }

        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        resultsContainerView.layer.cornerRadius = 18
        resultsContainerView.backgroundColor = UIColor.secondarySystemBackground
        resultsContainerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: resultsContainerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: resultsContainerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: resultsContainerView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: resultsContainerView.bottomAnchor, constant: -16)
        ])
    }

    private func render() {
        let snapshot = store.snapshot
        title = snapshot.tripInfo.title
        titleLabel?.text = "\(snapshot.tripInfo.title) Results"

        stackView.arrangedSubviews.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        for place in snapshot.searchResults {
            let button = UIButton(type: .system)
            button.contentHorizontalAlignment = .leading
            button.configuration = .plain()
            button.configuration?.title = "\(place.name) • \(place.visitDurationMinutes) min"
            button.tintColor = snapshot.selectedPlace?.placeID == place.placeID ? .systemBlue : .label
            button.accessibilityIdentifier = place.placeID
            button.addTarget(self, action: #selector(placeButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        if let selectedPlace = snapshot.selectedPlace {
            detailsButton?.configuration?.title = "View \(selectedPlace.name)"
            detailsButton?.setTitle("View \(selectedPlace.name)", for: .normal)
        }
    }

    @objc private func placeButtonTapped(_ sender: UIButton) {
        guard let placeID = sender.accessibilityIdentifier else {
            return
        }

        store.selectPlace(withID: placeID)
        render()
    }

    @objc private func prepareSelectedPlaceForSegue() {
        if let selectedPlaceID = store.snapshot.selectedPlace?.placeID {
            store.selectPlace(withID: selectedPlaceID)
        }
    }

    private func applyLayout() {
        guard
            let titleLabel,
            let resultsContainerView,
            let detailsButton
        else {
            return
        }

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        resultsContainerView.constrainMinimumHeight(to: 280)
        detailsButton.configuration = .filled()
        detailsButton.constrainHeight(to: 50)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [titleLabel, resultsContainerView, detailsButton],
            topPadding: 28,
            horizontalPadding: 24,
            bottomPadding: 24,
            spacing: 20
        )

        stackView.setCustomSpacing(24, after: titleLabel)
    }
}
