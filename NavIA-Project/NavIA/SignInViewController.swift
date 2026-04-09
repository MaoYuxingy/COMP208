//
//  SignInViewController.swift
//  NavIA
//

import UIKit

final class SignInViewController: UIViewController {
    private enum AuthMode {
        case signIn
        case createAccount
    }

    private enum AuthStep {
        case emailEntry
        case passwordEntry
    }

    @IBOutlet private weak var accountTextField: UITextField!
    @IBOutlet private weak var passwordTextField: UITextField!
    @IBOutlet private weak var signInButton: UIButton!

    private let authService: Authenticating = AuthService.shared
    private let sessionStore = UserSessionStore.shared

    private let helperLabel = UILabel()
    private let dividerLabel = UILabel()
    private let legalLabel = UILabel()
    private let modeSwitchButton = UIButton(type: .system)

    private weak var titleLabel: UILabel?
    private weak var subtitleLabel: UILabel?
    private weak var googleButton: UIButton?
    private weak var appleButton: UIButton?

    private var authMode: AuthMode = .createAccount
    private var authStep: AuthStep = .emailEntry

    override func viewDidLoad() {
        super.viewDidLoad()

        let labels = view.descendants(of: UILabel.self)
        let secondaryButtons = view.descendants(of: UIButton.self).filter { $0 !== signInButton }

        titleLabel = labels.first
        subtitleLabel = labels.dropFirst().first
        googleButton = secondaryButtons.first
        appleButton = secondaryButtons.dropFirst().first

        configureFields()
        configureSupplementaryViews()
        configureButtons()
        applyLayout()
        renderAuthScreen()
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

        guard !email.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter your email address.")
            return
        }

        guard authStep == .passwordEntry else {
            authStep = .passwordEntry
            renderAuthScreen()
            passwordTextField.becomeFirstResponder()
            return
        }

        let password = passwordTextField.text ?? ""
        guard !password.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter your password.")
            return
        }

        setLoading(true)

        switch authMode {
        case .signIn:
            authService.signIn(request: SignInRequest(email: email, password: password)) { [weak self] result in
                self?.handleAuthResult(result, failureTitle: "Login Failed")
            }

        case .createAccount:
            authService.signUp(
                request: SignUpRequest(
                    email: email,
                    password: password,
                    displayName: nil
                )
            ) { [weak self] result in
                self?.handleAuthResult(result, failureTitle: "Registration Failed")
            }
        }
    }

    @objc private func modeSwitchTapped() {
        authMode = authMode == .createAccount ? .signIn : .createAccount
        authStep = .emailEntry
        passwordTextField.text = nil
        renderAuthScreen()
    }

    private func configureFields() {
        accountTextField.keyboardType = .emailAddress
        accountTextField.textContentType = .emailAddress
        accountTextField.autocapitalizationType = .none
        accountTextField.autocorrectionType = .no
        accountTextField.placeholder = "email@domain.com"

        passwordTextField.isSecureTextEntry = true
        passwordTextField.textContentType = .password
        passwordTextField.placeholder = "Password"
    }

    private func configureSupplementaryViews() {
        helperLabel.numberOfLines = 0
        helperLabel.textAlignment = .center
        helperLabel.font = .systemFont(ofSize: 13)
        helperLabel.textColor = .secondaryLabel

        dividerLabel.text = "or"
        dividerLabel.font = .systemFont(ofSize: 12)
        dividerLabel.textAlignment = .center
        dividerLabel.textColor = .tertiaryLabel

        legalLabel.numberOfLines = 0
        legalLabel.font = .systemFont(ofSize: 11)
        legalLabel.textAlignment = .center
        legalLabel.textColor = .tertiaryLabel
        legalLabel.text = "By clicking continue, you agree to our Terms of Service and Privacy Policy."

        modeSwitchButton.configuration = .plain()
        modeSwitchButton.addTarget(self, action: #selector(modeSwitchTapped), for: .touchUpInside)
    }

    private func configureButtons() {
        googleButton?.configuration = .gray()
        googleButton?.configuration?.title = "Continue with Google"
        googleButton?.setTitle("Continue with Google", for: .normal)
        googleButton?.isEnabled = false
        googleButton?.alpha = 0.75

        appleButton?.configuration = .gray()
        appleButton?.configuration?.title = "Continue with Apple"
        appleButton?.setTitle("Continue with Apple", for: .normal)
        appleButton?.isEnabled = false
        appleButton?.alpha = 0.75
    }

    private func renderAuthScreen() {
        guard
            let titleLabel,
            let subtitleLabel
        else {
            return
        }

        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.text = "NavIA"

        subtitleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let subtitleText: String
        let helperText: String
        let primaryButtonTitle: String
        let switchTitle: String

        switch (authMode, authStep) {
        case (.createAccount, .emailEntry):
            subtitleText = "Create an account"
            helperText = "Enter your email to sign up for this app."
            primaryButtonTitle = "Continue"
            switchTitle = "Already have an account? Sign In"

        case (.signIn, .emailEntry):
            subtitleText = "Sign in"
            helperText = "Enter your email to sign in to this app."
            primaryButtonTitle = "Continue"
            switchTitle = "Need an account? Create Account"

        case (.createAccount, .passwordEntry):
            subtitleText = "Create an account"
            helperText = "Enter your password to finish creating your account."
            primaryButtonTitle = "Create Account"
            switchTitle = "Already have an account? Sign In"

        case (.signIn, .passwordEntry):
            subtitleText = "Sign in"
            helperText = "Enter your password to continue."
            primaryButtonTitle = "Sign In"
            switchTitle = "Need an account? Create Account"
        }

        subtitleLabel.text = subtitleText
        helperLabel.text = helperText
        passwordTextField.isHidden = authStep == .emailEntry

        signInButton.configuration = .filled()
        signInButton.configuration?.baseBackgroundColor = .label
        signInButton.configuration?.baseForegroundColor = .systemBackground
        signInButton.configuration?.title = primaryButtonTitle
        signInButton.setTitle(primaryButtonTitle, for: .normal)

        modeSwitchButton.configuration?.title = switchTitle
        modeSwitchButton.setTitle(switchTitle, for: .normal)
    }

    private func setLoading(_ isLoading: Bool) {
        signInButton.isEnabled = !isLoading
        modeSwitchButton.isEnabled = !isLoading
        accountTextField.isEnabled = !isLoading
        passwordTextField.isEnabled = !isLoading

        let primaryTitle: String
        switch authMode {
        case .signIn:
            primaryTitle = isLoading ? "Signing In..." : "Sign In"
        case .createAccount:
            primaryTitle = isLoading ? "Creating Account..." : "Create Account"
        }

        if authStep == .emailEntry && !isLoading {
            signInButton.configuration?.title = "Continue"
            signInButton.setTitle("Continue", for: .normal)
        } else {
            signInButton.configuration?.title = primaryTitle
            signInButton.setTitle(primaryTitle, for: .normal)
        }
    }

    private func handleAuthResult(_ result: Result<AuthSession, Error>, failureTitle: String) {
        setLoading(false)

        switch result {
        case .success(let session):
            sessionStore.updateSession(session)
            goToMainTab(animated: true)

        case .failure(let error):
            showAlert(title: failureTitle, message: error.localizedDescription)
        }
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

        accountTextField.constrainHeight(to: 44)
        passwordTextField.constrainHeight(to: 44)
        signInButton.constrainHeight(to: 50)
        googleButton.constrainHeight(to: 44)
        appleButton.constrainHeight(to: 44)

        let stackView = installScrollableContentStack(
            arrangedSubviews: [
                titleLabel,
                subtitleLabel,
                helperLabel,
                accountTextField,
                passwordTextField,
                signInButton,
                modeSwitchButton,
                dividerLabel,
                googleButton,
                appleButton,
                legalLabel
            ],
            topPadding: 72,
            horizontalPadding: 32,
            bottomPadding: 32,
            spacing: 14
        )

        stackView.setCustomSpacing(10, after: titleLabel)
        stackView.setCustomSpacing(28, after: helperLabel)
        stackView.setCustomSpacing(20, after: signInButton)
        stackView.setCustomSpacing(8, after: modeSwitchButton)
        stackView.setCustomSpacing(6, after: dividerLabel)
        stackView.setCustomSpacing(16, after: appleButton)
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
