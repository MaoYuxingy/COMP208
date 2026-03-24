//
//  AttractionDetailsViewController.swift
//  NavIA
//

import UIKit

final class AttractionDetailsViewController: UIViewController {
    private let store = AppContainer.shared.tripPlannerStore
    private let infoLabel = UILabel()

    private weak var titleLabel: UILabel?
    private weak var imageView: UIImageView?
    private weak var addToTripButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel = view.descendants(of: UILabel.self).first
        imageView = view.descendants(of: UIImageView.self).first
        addToTripButton = view.descendants(of: UIButton.self).first

        configureViews()
        applyLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    private func configureViews() {
        imageView?.image = UIImage(systemName: "mappin.and.ellipse.circle.fill")
        imageView?.tintColor = .systemTeal

        infoLabel.numberOfLines = 0
        infoLabel.font = .systemFont(ofSize: 14)
        infoLabel.textColor = .secondaryLabel
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)

        addToTripButton?.addTarget(self, action: #selector(addSelectedPlaceToTrip), for: .touchUpInside)
    }

    private func render() {
        guard let selectedPlace = store.snapshot.selectedPlace else {
            titleLabel?.text = "Details"
            infoLabel.text = "No attraction selected."
            return
        }

        titleLabel?.text = selectedPlace.name
        infoLabel.text = [
            "Name: \(selectedPlace.name)",
            "Visit duration: \(selectedPlace.visitDurationMinutes) min",
            "Open: \(selectedPlace.openTime) • Close: \(selectedPlace.closeTime)",
            "Coordinates: \(selectedPlace.latitude.formatted(.number.precision(.fractionLength(4)))), \(selectedPlace.longitude.formatted(.number.precision(.fractionLength(4))))"
        ].joined(separator: "\n")
    }

    @objc private func addSelectedPlaceToTrip() {
        guard let selectedPlace = store.snapshot.selectedPlace else {
            return
        }

        store.addPlace(selectedPlace)
    }

    private func applyLayout() {
        guard
            let titleLabel,
            let imageView,
            let addToTripButton
        else {
            return
        }

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        imageView.constrainHeight(to: 180)
        infoLabel.constrainMinimumHeight(to: 96)
        addToTripButton.configuration = .filled()
        addToTripButton.configuration?.title = "Add to Trip"
        addToTripButton.setTitle("Add to Trip", for: .normal)
        addToTripButton.constrainHeight(to: 50)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [titleLabel, imageView, infoLabel, addToTripButton],
            topPadding: 28,
            horizontalPadding: 24,
            bottomPadding: 24,
            spacing: 18
        )

        stackView.setCustomSpacing(24, after: titleLabel)
    }
}
