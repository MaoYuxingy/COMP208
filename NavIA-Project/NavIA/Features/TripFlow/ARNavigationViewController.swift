//
//  ARNavigationViewController.swift
//  NavIA
//

import UIKit

final class ARNavigationViewController: UIViewController {
    private let container = AppContainer.shared

    private weak var titleLabel: UILabel?
    private weak var nextStopLabel: UILabel?
    private weak var etaLabel: UILabel?
    private weak var previewContainerView: UIView?
    private weak var finishButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()

        let labels = view.descendants(of: UILabel.self)
        titleLabel = labels.first
        nextStopLabel = labels.dropFirst().first
        etaLabel = labels.dropFirst(2).first
        previewContainerView = view.subviews.first(where: { type(of: $0) == UIView.self })
        finishButton = view.descendants(of: UIButton.self).first
        applyLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    private func render() {
        let state = container.makeRoutePlannerViewModel().state
        let nextStop = state.optimizedPlaces.dropFirst().first ?? state.optimizedPlaces.first ?? "-"
        let estimatedMinutesRemaining = max(5, state.optimizedPlaces.isEmpty ? 0 : state.optimizedPlaces.count * 12)

        titleLabel?.text = "AR Navigation"
        nextStopLabel?.text = "Next Stop: \(nextStop)"
        etaLabel?.text = "ETA: \(estimatedMinutesRemaining) min"
    }

    private func applyLayout() {
        guard
            let titleLabel,
            let nextStopLabel,
            let etaLabel,
            let previewContainerView,
            let finishButton
        else {
            return
        }

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        nextStopLabel.numberOfLines = 0
        etaLabel.textColor = .secondaryLabel
        previewContainerView.layer.cornerRadius = 18
        previewContainerView.backgroundColor = .secondarySystemBackground
        previewContainerView.constrainMinimumHeight(to: 280)
        finishButton.configuration = .filled()
        finishButton.configuration?.title = "Finish Trip"
        finishButton.setTitle("Finish Trip", for: .normal)
        finishButton.constrainHeight(to: 50)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [titleLabel, previewContainerView, nextStopLabel, etaLabel, finishButton],
            topPadding: 28,
            horizontalPadding: 24,
            bottomPadding: 24,
            spacing: 18
        )

        stackView.setCustomSpacing(24, after: titleLabel)
    }
}
