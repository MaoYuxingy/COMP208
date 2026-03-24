//
//  SignInViewController.swift
//  NavIA
//

import UIKit

final class SignInViewController: UIViewController {
    @IBOutlet private weak var accountTextField: UITextField!
    @IBOutlet private weak var passwordTextField: UITextField!
    @IBOutlet private weak var signInButton: UIButton!

    private let authService: Authenticating = AuthService.shared
    private let sessionStore = UserSessionStore.shared

    private weak var titleLabel: UILabel?
    private weak var subtitleLabel: UILabel?
    private weak var googleButton: UIButton?
    private weak var appleButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        let labels = view.descendants(of: UILabel.self)
        let buttons = view.descendants(of: UIButton.self)

        titleLabel = labels.first
        subtitleLabel = labels.dropFirst().first
        googleButton = buttons.dropFirst().first
        appleButton = buttons.dropFirst(2).first

        passwordTextField.isSecureTextEntry = true
        accountTextField.keyboardType = .emailAddress
        accountTextField.autocapitalizationType = .none
        accountTextField.autocorrectionType = .no

        applyLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard sessionStore.isAuthenticated else {
            return
        }

        goToMainTab(animated: false)
    }

    @IBAction private func signInTapped(_ sender: UIButton) {
        let email = accountTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordTextField.text ?? ""

        guard !email.isEmpty, !password.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter both email and password.")
            return
        }

        setLoading(true)

        authService.signIn(request: SignInRequest(email: email, password: password)) { [weak self] result in
            guard let self else { return }

            self.setLoading(false)

            switch result {
            case .success(let session):
                self.sessionStore.updateSession(session)
                self.goToMainTab(animated: true)

            case .failure(let error):
                self.showAlert(title: "Login Failed", message: error.localizedDescription)
            }
        }
    }

    private func setLoading(_ isLoading: Bool) {
        signInButton.isEnabled = !isLoading
        signInButton.configuration?.title = isLoading ? "Signing In..." : "Sign In"
        signInButton.setTitle(isLoading ? "Signing In..." : "Sign In", for: .normal)
    }

    private func applyLayout() {
        guard
            let titleLabel,
            let subtitleLabel,
            let googleButton,
            let appleButton
        else {
            return
        }

        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textAlignment = .center
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = .secondaryLabel

        [accountTextField, passwordTextField].forEach {
            $0?.constrainHeight(to: 44)
        }

        signInButton.configuration = .filled()
        signInButton.configuration?.title = "Sign In"
        signInButton.setTitle("Sign In", for: .normal)
        signInButton.constrainHeight(to: 50)
        googleButton.configuration = .bordered()
        googleButton.configuration?.title = "Continue with Google"
        googleButton.setTitle("Continue with Google", for: .normal)
        googleButton.constrainHeight(to: 50)
        appleButton.configuration = .bordered()
        appleButton.configuration?.title = "Continue with Apple"
        appleButton.setTitle("Continue with Apple", for: .normal)
        appleButton.constrainHeight(to: 50)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [
                titleLabel,
                subtitleLabel,
                accountTextField,
                passwordTextField,
                signInButton,
                googleButton,
                appleButton
            ],
            topPadding: 56,
            horizontalPadding: 24,
            bottomPadding: 32,
            spacing: 18
        )

        stackView.setCustomSpacing(8, after: titleLabel)
        stackView.setCustomSpacing(28, after: subtitleLabel)
    }

    private func goToMainTab(animated: Bool) {
        let storyboard = UIStoryboard(name: "MainTab", bundle: nil)

        guard let destination = storyboard.instantiateInitialViewController() else {
            showAlert(title: "Navigation Error", message: "MainTab initial view controller is not set.")
            return
        }

        guard let windowScene = view.window?.windowScene else {
            present(destination, animated: animated)
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = destination
        window.makeKeyAndVisible()

        if let sceneDelegate = windowScene.delegate as? SceneDelegate {
            sceneDelegate.window = window
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
