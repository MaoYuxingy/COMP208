//
//  AppRootFactory.swift
//  NavIA
//

import UIKit

struct AppRootFactory {
    private let container: AppContainer

    init(container: AppContainer = .shared) {
        self.container = container
    }

    func makeRootViewController() -> UIViewController {
        if container.sessionStore.isAuthenticated, let mainTabRoot = instantiateInitialViewController(named: "MainTab") {
            return mainTabRoot
        }

        if let authRoot = instantiateInitialViewController(named: "Auth") {
            return authRoot
        }

        if let mainTabRoot = instantiateInitialViewController(named: "MainTab") {
            return mainTabRoot
        }

        if let tripFlowRoot = instantiateInitialViewController(named: "TripFlow") {
            return tripFlowRoot
        }

        return UINavigationController(
            rootViewController: DevelopmentDashboardViewController(
                viewModel: container.makeRoutePlannerViewModel()
            )
        )
    }

    private func instantiateInitialViewController(named storyboardName: String) -> UIViewController? {
        UIStoryboard(name: storyboardName, bundle: nil).instantiateInitialViewController()
    }
}
