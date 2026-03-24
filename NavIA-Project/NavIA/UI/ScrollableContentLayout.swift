//
//  ScrollableContentLayout.swift
//  NavIA
//

import UIKit

extension UIViewController {
    @discardableResult
    func installScrollableContentStack(
        arrangedSubviews: [UIView],
        topPadding: CGFloat = 24,
        horizontalPadding: CGFloat = 24,
        bottomPadding: CGFloat = 24,
        spacing: CGFloat = 16
    ) -> UIStackView {
        let scrollView = UIScrollView()
        let contentView = UIView()
        let stackView = UIStackView()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        stackView.axis = .vertical
        stackView.spacing = spacing
        stackView.alignment = .fill
        stackView.distribution = .fill

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: topPadding),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalPadding),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalPadding),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -bottomPadding)
        ])

        arrangedSubviews.forEach { arrangedSubview in
            arrangedSubview.removeFromSuperview()
            arrangedSubview.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(arrangedSubview)
        }

        return stackView
    }
}

extension UIView {
    @discardableResult
    func constrainHeight(to constant: CGFloat) -> NSLayoutConstraint {
        let constraint = heightAnchor.constraint(equalToConstant: constant)
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func constrainMinimumHeight(to constant: CGFloat) -> NSLayoutConstraint {
        let constraint = heightAnchor.constraint(greaterThanOrEqualToConstant: constant)
        constraint.isActive = true
        return constraint
    }
}
