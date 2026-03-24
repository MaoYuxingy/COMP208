//
//  AppNavigator.swift
//  NavIA
//

import UIKit

enum AppNavigator {
    static func makeTripFlowNavigationController(startingAt storyboardIdentifier: String? = nil) -> UINavigationController? {
        let storyboard = UIStoryboard(name: "TripFlow", bundle: nil)

        let rootViewController: UIViewController?
        if let storyboardIdentifier {
            rootViewController = storyboard.instantiateViewController(withIdentifier: storyboardIdentifier)
        } else {
            rootViewController = storyboard.instantiateInitialViewController()
        }

        guard let rootViewController else {
            return nil
        }

        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.modalPresentationStyle = .fullScreen
        return navigationController
    }

    static func replaceRoot(using windowScene: UIWindowScene?) {
        guard let windowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = AppRootFactory().makeRootViewController()
        window.makeKeyAndVisible()

        if let sceneDelegate = windowScene.delegate as? SceneDelegate {
            sceneDelegate.window = window
        }
    }
}

extension UIViewController {
    func installCloseButtonIfNeeded() {
        guard navigationController?.viewControllers.first === self,
              presentingViewController != nil
        else {
            return
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closePresentedFlow)
        )
    }

    func presentSimpleAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }

    @objc private func closePresentedFlow() {
        dismiss(animated: true)
    }
}
