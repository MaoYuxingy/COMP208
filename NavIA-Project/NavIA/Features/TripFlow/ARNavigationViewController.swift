//
//  ARNavigationViewController.swift
//  NavIA
//

import AVFoundation
import CoreLocation
import MapKit
import UIKit

final class ARNavigationViewController: UIViewController {
    private enum PreviewMode {
        case live
        case map
    }

    private enum InstructionStyle {
        case left
        case right
        case straight
    }

    private struct NavigationSnapshot {
        let orderedPlaces: [Place]
        let totalLegs: Int
        let fromPlace: Place
        let toPlace: Place
        let titleText: String
        let distanceText: String
        let metaText: String
        let progressText: String
        let style: InstructionStyle
    }

    private final class RouteStopAnnotation: NSObject, MKAnnotation {
        let coordinate: CLLocationCoordinate2D
        let title: String?
        let subtitle: String?
        let markerText: String

        init(coordinate: CLLocationCoordinate2D, title: String, subtitle: String?, markerText: String) {
            self.coordinate = coordinate
            self.title = title
            self.subtitle = subtitle
            self.markerText = markerText
        }
    }

    private final class GradientOverlayView: UIView {
        override class var layerClass: AnyClass {
            CAGradientLayer.self
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false

            let layer = self.layer as? CAGradientLayer
            layer?.colors = [
                UIColor.black.withAlphaComponent(0.55).cgColor,
                UIColor.black.withAlphaComponent(0.12).cgColor,
                UIColor.black.withAlphaComponent(0.10).cgColor,
                UIColor.black.withAlphaComponent(0.65).cgColor
            ]
            layer?.locations = [0.0, 0.22, 0.58, 1.0]
            layer?.startPoint = CGPoint(x: 0.5, y: 0.0)
            layer?.endPoint = CGPoint(x: 0.5, y: 1.0)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    private final class DemoRoadBackdropView: UIView {
        private let skyLayer = CAGradientLayer()
        private let vignetteLayer = CAGradientLayer()
        private let roadLayer = CAShapeLayer()
        private let laneLayer = CAShapeLayer()
        private let sideLayer = CAShapeLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false

            skyLayer.colors = [
                UIColor(red: 0.74, green: 0.79, blue: 0.88, alpha: 1).cgColor,
                UIColor(red: 0.55, green: 0.60, blue: 0.68, alpha: 1).cgColor,
                UIColor(red: 0.27, green: 0.28, blue: 0.33, alpha: 1).cgColor
            ]
            skyLayer.locations = [0.0, 0.45, 1.0]
            layer.addSublayer(skyLayer)

            sideLayer.fillColor = UIColor(white: 0.30, alpha: 0.75).cgColor
            layer.addSublayer(sideLayer)

            roadLayer.fillColor = UIColor(white: 0.18, alpha: 1).cgColor
            roadLayer.strokeColor = UIColor(white: 0.24, alpha: 1).cgColor
            roadLayer.lineWidth = 2
            layer.addSublayer(roadLayer)

            laneLayer.strokeColor = UIColor(white: 1.0, alpha: 0.78).cgColor
            laneLayer.fillColor = UIColor.clear.cgColor
            laneLayer.lineWidth = 5
            laneLayer.lineDashPattern = [12, 14]
            laneLayer.lineCap = .round
            layer.addSublayer(laneLayer)

            vignetteLayer.colors = [
                UIColor.black.withAlphaComponent(0.0).cgColor,
                UIColor.black.withAlphaComponent(0.08).cgColor,
                UIColor.black.withAlphaComponent(0.32).cgColor
            ]
            vignetteLayer.locations = [0.0, 0.6, 1.0]
            vignetteLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            vignetteLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
            layer.addSublayer(vignetteLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            skyLayer.frame = bounds
            vignetteLayer.frame = bounds

            let width = bounds.width
            let height = bounds.height

            let leftBuildings = UIBezierPath()
            leftBuildings.append(UIBezierPath(rect: CGRect(x: 0, y: height * 0.22, width: width * 0.16, height: height * 0.38)))
            leftBuildings.append(UIBezierPath(rect: CGRect(x: width * 0.12, y: height * 0.16, width: width * 0.10, height: height * 0.32)))

            let rightBuildings = UIBezierPath()
            rightBuildings.append(UIBezierPath(rect: CGRect(x: width * 0.76, y: height * 0.18, width: width * 0.16, height: height * 0.42)))
            rightBuildings.append(UIBezierPath(rect: CGRect(x: width * 0.86, y: height * 0.22, width: width * 0.10, height: height * 0.30)))

            leftBuildings.append(rightBuildings)
            sideLayer.path = leftBuildings.cgPath

            let roadPath = UIBezierPath()
            roadPath.move(to: CGPoint(x: width * 0.18, y: height))
            roadPath.addLine(to: CGPoint(x: width * 0.40, y: height * 0.34))
            roadPath.addLine(to: CGPoint(x: width * 0.60, y: height * 0.34))
            roadPath.addLine(to: CGPoint(x: width * 0.82, y: height))
            roadPath.close()
            roadLayer.path = roadPath.cgPath

            let lanePath = UIBezierPath()
            lanePath.move(to: CGPoint(x: width * 0.50, y: height))
            lanePath.addLine(to: CGPoint(x: width * 0.50, y: height * 0.36))
            laneLayer.path = lanePath.cgPath
        }
    }

    private final class NavigationArrowOverlayView: UIView {
        enum Direction {
            case left
            case right
            case straight
        }

        var direction: Direction = .straight {
            didSet { setNeedsLayout() }
        }

        private let glowLayer = CAShapeLayer()
        private let coreLayer = CAShapeLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false

            glowLayer.fillColor = UIColor.clear.cgColor
            glowLayer.strokeColor = UIColor(red: 0.18, green: 0.92, blue: 1.0, alpha: 0.55).cgColor
            glowLayer.lineWidth = 34
            glowLayer.lineCap = .round
            glowLayer.lineJoin = .round
            glowLayer.shadowColor = UIColor(red: 0.22, green: 0.92, blue: 1.0, alpha: 1).cgColor
            glowLayer.shadowOpacity = 0.92
            glowLayer.shadowRadius = 22
            glowLayer.shadowOffset = .zero

            coreLayer.fillColor = UIColor.clear.cgColor
            coreLayer.strokeColor = UIColor(red: 0.42, green: 0.98, blue: 1.0, alpha: 0.96).cgColor
            coreLayer.lineWidth = 18
            coreLayer.lineCap = .round
            coreLayer.lineJoin = .round

            layer.addSublayer(glowLayer)
            layer.addSublayer(coreLayer)
            startPulseAnimation()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let path = makePath(in: bounds)
            glowLayer.frame = bounds
            coreLayer.frame = bounds
            glowLayer.path = path.cgPath
            coreLayer.path = path.cgPath
        }

        private func startPulseAnimation() {
            let opacityAnimation = CABasicAnimation(keyPath: "opacity")
            opacityAnimation.fromValue = 0.7
            opacityAnimation.toValue = 1.0
            opacityAnimation.duration = 0.9
            opacityAnimation.autoreverses = true
            opacityAnimation.repeatCount = .infinity
            glowLayer.add(opacityAnimation, forKey: "pulse")

            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 0.985
            scaleAnimation.toValue = 1.02
            scaleAnimation.duration = 0.9
            scaleAnimation.autoreverses = true
            scaleAnimation.repeatCount = .infinity
            layer.add(scaleAnimation, forKey: "breathe")
        }

        private func makePath(in rect: CGRect) -> UIBezierPath {
            let path = UIBezierPath()
            let width = rect.width
            let height = rect.height
            let start = CGPoint(x: width * 0.50, y: height * 0.88)

            switch direction {
            case .left:
                let turn = CGPoint(x: width * 0.50, y: height * 0.56)
                let end = CGPoint(x: width * 0.22, y: height * 0.30)
                path.move(to: start)
                path.addCurve(
                    to: turn,
                    controlPoint1: CGPoint(x: width * 0.50, y: height * 0.76),
                    controlPoint2: CGPoint(x: width * 0.50, y: height * 0.66)
                )
                path.addCurve(
                    to: end,
                    controlPoint1: CGPoint(x: width * 0.50, y: height * 0.44),
                    controlPoint2: CGPoint(x: width * 0.38, y: height * 0.30)
                )
                path.move(to: end)
                path.addLine(to: CGPoint(x: width * 0.34, y: height * 0.28))
                path.move(to: end)
                path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.42))

            case .right:
                let turn = CGPoint(x: width * 0.50, y: height * 0.56)
                let end = CGPoint(x: width * 0.78, y: height * 0.30)
                path.move(to: start)
                path.addCurve(
                    to: turn,
                    controlPoint1: CGPoint(x: width * 0.50, y: height * 0.76),
                    controlPoint2: CGPoint(x: width * 0.50, y: height * 0.66)
                )
                path.addCurve(
                    to: end,
                    controlPoint1: CGPoint(x: width * 0.50, y: height * 0.44),
                    controlPoint2: CGPoint(x: width * 0.62, y: height * 0.30)
                )
                path.move(to: end)
                path.addLine(to: CGPoint(x: width * 0.66, y: height * 0.28))
                path.move(to: end)
                path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.42))

            case .straight:
                let end = CGPoint(x: width * 0.50, y: height * 0.22)
                path.move(to: start)
                path.addCurve(
                    to: end,
                    controlPoint1: CGPoint(x: width * 0.50, y: height * 0.74),
                    controlPoint2: CGPoint(x: width * 0.50, y: height * 0.42)
                )
                path.move(to: end)
                path.addLine(to: CGPoint(x: width * 0.38, y: height * 0.34))
                path.move(to: end)
                path.addLine(to: CGPoint(x: width * 0.62, y: height * 0.34))
            }

            return path
        }
    }

    private let container = AppContainer.shared
    private let cameraSessionQueue = DispatchQueue(label: "NavIA.camera.session")

    private let livePreviewHost = UIView()
    private let fallbackRoadView = DemoRoadBackdropView()
    private let mapView = MKMapView()
    private let scrimView = GradientOverlayView()
    private let arrowView = NavigationArrowOverlayView()

    private let backButtonBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let backButton = UIButton(type: .system)
    private let screenTitleLabel = UILabel()

    private let cautionBannerView = UIView()
    private let cautionIconView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
    private let cautionLabel = UILabel()

    private let progressPillView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let progressLabel = UILabel()

    private let instructionCardView = UIView()
    private let instructionLabel = UILabel()
    private let distanceLabel = UILabel()
    private let metaLabel = UILabel()
    private let modeToggleButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    private var previewMode: PreviewMode = .live
    private var currentLegIndex = 0

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didRequestCameraAccess = false

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.subviews.forEach { $0.removeFromSuperview() }
        view.backgroundColor = .black

        configurePreviewSurface()
        configureOverlayChrome()
        configureActions()
        bindViewModel()
        render(container.makeRoutePlannerViewModel().state)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        setNeedsStatusBarAppearanceUpdate()
        updatePreviewMode(animated: false)
        render(container.makeRoutePlannerViewModel().state)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updatePreviewMode(animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        stopCameraSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = livePreviewHost.bounds
    }

    private func configurePreviewSurface() {
        [livePreviewHost, mapView, scrimView, arrowView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        fallbackRoadView.translatesAutoresizingMaskIntoConstraints = false
        livePreviewHost.addSubview(fallbackRoadView)

        livePreviewHost.clipsToBounds = true
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isPitchEnabled = false

        NSLayoutConstraint.activate([
            livePreviewHost.topAnchor.constraint(equalTo: view.topAnchor),
            livePreviewHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            livePreviewHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            livePreviewHost.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            fallbackRoadView.topAnchor.constraint(equalTo: livePreviewHost.topAnchor),
            fallbackRoadView.leadingAnchor.constraint(equalTo: livePreviewHost.leadingAnchor),
            fallbackRoadView.trailingAnchor.constraint(equalTo: livePreviewHost.trailingAnchor),
            fallbackRoadView.bottomAnchor.constraint(equalTo: livePreviewHost.bottomAnchor),

            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrimView.topAnchor.constraint(equalTo: view.topAnchor),
            scrimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            arrowView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            arrowView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 4),
            arrowView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.52),
            arrowView.heightAnchor.constraint(equalTo: arrowView.widthAnchor, multiplier: 1.08)
        ])
    }

    private func configureOverlayChrome() {
        let safeArea = view.safeAreaLayoutGuide

        backButtonBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        backButtonBackgroundView.clipsToBounds = true
        backButtonBackgroundView.layer.cornerRadius = 22
        view.addSubview(backButtonBackgroundView)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .white
        backButtonBackgroundView.contentView.addSubview(backButton)

        screenTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        screenTitleLabel.text = "Live Navigation"
        screenTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        screenTitleLabel.textColor = .white
        screenTitleLabel.textAlignment = .center
        view.addSubview(screenTitleLabel)

        cautionBannerView.translatesAutoresizingMaskIntoConstraints = false
        cautionBannerView.backgroundColor = UIColor(red: 0.97, green: 0.80, blue: 0.28, alpha: 0.96)
        cautionBannerView.layer.cornerRadius = 14
        cautionBannerView.clipsToBounds = true
        view.addSubview(cautionBannerView)

        cautionIconView.translatesAutoresizingMaskIntoConstraints = false
        cautionIconView.tintColor = UIColor(red: 0.40, green: 0.28, blue: 0.02, alpha: 1)
        cautionBannerView.addSubview(cautionIconView)

        cautionLabel.translatesAutoresizingMaskIntoConstraints = false
        cautionLabel.text = "SAFETY FIRST: Stay aware of your surroundings and traffic."
        cautionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        cautionLabel.textColor = UIColor(red: 0.30, green: 0.22, blue: 0.03, alpha: 1)
        cautionLabel.numberOfLines = 2
        cautionBannerView.addSubview(cautionLabel)

        progressPillView.translatesAutoresizingMaskIntoConstraints = false
        progressPillView.clipsToBounds = true
        progressPillView.layer.cornerRadius = 18
        view.addSubview(progressPillView)

        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        progressLabel.textColor = .white
        progressPillView.contentView.addSubview(progressLabel)

        instructionCardView.translatesAutoresizingMaskIntoConstraints = false
        instructionCardView.backgroundColor = UIColor.black.withAlphaComponent(0.68)
        instructionCardView.layer.cornerRadius = 24
        instructionCardView.layer.borderWidth = 1
        instructionCardView.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        view.addSubview(instructionCardView)

        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.font = .systemFont(ofSize: 24, weight: .bold)
        instructionLabel.textColor = .white
        instructionLabel.numberOfLines = 2

        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.font = .systemFont(ofSize: 15, weight: .medium)
        distanceLabel.textColor = UIColor.white.withAlphaComponent(0.86)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .systemFont(ofSize: 13, weight: .regular)
        metaLabel.textColor = UIColor.white.withAlphaComponent(0.74)
        metaLabel.numberOfLines = 2

        modeToggleButton.translatesAutoresizingMaskIntoConstraints = false
        modeToggleButton.configuration = .gray()
        modeToggleButton.configuration?.cornerStyle = .capsule
        modeToggleButton.configuration?.baseForegroundColor = .white
        modeToggleButton.configuration?.baseBackgroundColor = UIColor.white.withAlphaComponent(0.12)
        modeToggleButton.configuration?.title = "Switch to 2D Map"

        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.configuration = .filled()
        nextButton.configuration?.cornerStyle = .capsule
        nextButton.configuration?.baseBackgroundColor = .white
        nextButton.configuration?.baseForegroundColor = .black
        nextButton.configuration?.title = "Next Stop"

        let buttonRow = UIStackView(arrangedSubviews: [modeToggleButton, nextButton])
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually

        instructionCardView.addSubview(instructionLabel)
        instructionCardView.addSubview(distanceLabel)
        instructionCardView.addSubview(metaLabel)
        instructionCardView.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            backButtonBackgroundView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 6),
            backButtonBackgroundView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            backButtonBackgroundView.widthAnchor.constraint(equalToConstant: 44),
            backButtonBackgroundView.heightAnchor.constraint(equalToConstant: 44),

            backButton.centerXAnchor.constraint(equalTo: backButtonBackgroundView.contentView.centerXAnchor),
            backButton.centerYAnchor.constraint(equalTo: backButtonBackgroundView.contentView.centerYAnchor),

            screenTitleLabel.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
            screenTitleLabel.centerYAnchor.constraint(equalTo: backButtonBackgroundView.centerYAnchor),
            screenTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButtonBackgroundView.trailingAnchor, constant: 12),

            cautionBannerView.topAnchor.constraint(equalTo: backButtonBackgroundView.bottomAnchor, constant: 12),
            cautionBannerView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            cautionBannerView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),

            cautionIconView.leadingAnchor.constraint(equalTo: cautionBannerView.leadingAnchor, constant: 12),
            cautionIconView.centerYAnchor.constraint(equalTo: cautionBannerView.centerYAnchor),

            cautionLabel.topAnchor.constraint(equalTo: cautionBannerView.topAnchor, constant: 10),
            cautionLabel.leadingAnchor.constraint(equalTo: cautionIconView.trailingAnchor, constant: 8),
            cautionLabel.trailingAnchor.constraint(equalTo: cautionBannerView.trailingAnchor, constant: -12),
            cautionLabel.bottomAnchor.constraint(equalTo: cautionBannerView.bottomAnchor, constant: -10),

            progressPillView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            progressPillView.bottomAnchor.constraint(equalTo: instructionCardView.topAnchor, constant: -16),

            progressLabel.topAnchor.constraint(equalTo: progressPillView.contentView.topAnchor, constant: 10),
            progressLabel.leadingAnchor.constraint(equalTo: progressPillView.contentView.leadingAnchor, constant: 14),
            progressLabel.trailingAnchor.constraint(equalTo: progressPillView.contentView.trailingAnchor, constant: -14),
            progressLabel.bottomAnchor.constraint(equalTo: progressPillView.contentView.bottomAnchor, constant: -10),

            instructionCardView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            instructionCardView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            instructionCardView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -14),

            instructionLabel.topAnchor.constraint(equalTo: instructionCardView.topAnchor, constant: 18),
            instructionLabel.leadingAnchor.constraint(equalTo: instructionCardView.leadingAnchor, constant: 18),
            instructionLabel.trailingAnchor.constraint(equalTo: instructionCardView.trailingAnchor, constant: -18),

            distanceLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 8),
            distanceLabel.leadingAnchor.constraint(equalTo: instructionLabel.leadingAnchor),
            distanceLabel.trailingAnchor.constraint(equalTo: instructionLabel.trailingAnchor),

            metaLabel.topAnchor.constraint(equalTo: distanceLabel.bottomAnchor, constant: 8),
            metaLabel.leadingAnchor.constraint(equalTo: instructionLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: instructionLabel.trailingAnchor),

            buttonRow.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 16),
            buttonRow.leadingAnchor.constraint(equalTo: instructionLabel.leadingAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: instructionLabel.trailingAnchor),
            buttonRow.bottomAnchor.constraint(equalTo: instructionCardView.bottomAnchor, constant: -18),

            modeToggleButton.heightAnchor.constraint(equalToConstant: 42),
            nextButton.heightAnchor.constraint(equalToConstant: 42)
        ])
    }

    private func configureActions() {
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        modeToggleButton.addTarget(self, action: #selector(modeToggleButtonTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }

    private func bindViewModel() {
        container.makeRoutePlannerViewModel().onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
    }

    private func render(_ state: RoutePlannerViewModel.ViewState) {
        if let snapshot = makeNavigationSnapshot(for: state) {
            instructionLabel.text = snapshot.titleText
            distanceLabel.text = snapshot.distanceText
            metaLabel.text = snapshot.metaText
            progressLabel.text = snapshot.progressText
            nextButton.configuration?.title = currentLegIndex < snapshot.totalLegs - 1 ? "Next Stop" : "Finish Trip"
            arrowView.direction = arrowDirection(for: snapshot.style)
            arrowView.isHidden = previewMode == .map
            renderMap(for: state, snapshot: snapshot)
        } else {
            let fallbackMessage = state.errorMessage ?? "Generate a route first, then this screen will guide you through each stop."
            instructionLabel.text = "Navigation Unavailable"
            distanceLabel.text = "Route guidance is not ready yet."
            metaLabel.text = fallbackMessage
            progressLabel.text = "No active navigation"
            nextButton.configuration?.title = "View Summary"
            arrowView.isHidden = true
            renderMap(for: state, snapshot: nil)
        }

        cautionBannerView.isHidden = previewMode == .map
        screenTitleLabel.text = previewMode == .live ? "Live Navigation" : "2D Route View"
        modeToggleButton.configuration?.title = previewMode == .live ? "Switch to 2D Map" : "Switch to Live View"
        updatePreviewMode(animated: false)
    }

    private func makeNavigationSnapshot(for state: RoutePlannerViewModel.ViewState) -> NavigationSnapshot? {
        let orderedPlaces = orderedPlaces(for: state)
        let totalLegs = max(orderedPlaces.count - 1, 0)
        guard totalLegs > 0 else {
            return nil
        }

        currentLegIndex = min(currentLegIndex, max(totalLegs - 1, 0))

        let fromPlace = orderedPlaces[currentLegIndex]
        let toPlace = orderedPlaces[currentLegIndex + 1]
        let style = instructionStyle(from: fromPlace.coordinate, to: toPlace.coordinate)
        let segmentDistanceMeters = distanceMeters(for: state, orderedPlaces: orderedPlaces, legIndex: currentLegIndex)
        let segmentMinutes = estimatedSegmentMinutes(for: state, totalLegs: totalLegs)
        let remainingMinutes = max(segmentMinutes, segmentMinutes * (totalLegs - currentLegIndex))
        let etaDate = Date().addingTimeInterval(TimeInterval(segmentMinutes * 60))
        let etaText = DateFormatter.localizedString(from: etaDate, dateStyle: .none, timeStyle: .short)

        return NavigationSnapshot(
            orderedPlaces: orderedPlaces,
            totalLegs: totalLegs,
            fromPlace: fromPlace,
            toPlace: toPlace,
            titleText: instructionTitle(for: style, destination: toPlace.name),
            distanceText: "In \(formattedDistance(segmentDistanceMeters))",
            metaText: "ETA \(etaText) • \(remainingMinutes) mins left • Next stop: \(toPlace.name)",
            progressText: "Leg \(currentLegIndex + 1) of \(totalLegs)",
            style: style
        )
    }

    private func updatePreviewMode(animated: Bool) {
        let showLivePreview = previewMode == .live
        let applyVisibility = {
            self.livePreviewHost.alpha = showLivePreview ? 1 : 0
            self.mapView.alpha = showLivePreview ? 0 : 1
            self.livePreviewHost.isHidden = !showLivePreview
            self.mapView.isHidden = showLivePreview
            self.arrowView.isHidden = !showLivePreview || self.instructionLabel.text == "Navigation Unavailable"
        }

        if animated {
            livePreviewHost.isHidden = false
            mapView.isHidden = false
            UIView.animate(withDuration: 0.2) {
                self.livePreviewHost.alpha = showLivePreview ? 1 : 0
                self.mapView.alpha = showLivePreview ? 0 : 1
                self.arrowView.alpha = showLivePreview ? 1 : 0
            } completion: { _ in
                applyVisibility()
            }
        } else {
            arrowView.alpha = showLivePreview ? 1 : 0
            applyVisibility()
        }

        if showLivePreview {
            startCameraIfPossible()
        } else {
            stopCameraSession()
        }
    }

    private func startCameraIfPossible() {
        #if targetEnvironment(simulator)
        fallbackRoadView.isHidden = false
        return
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStartCameraSession()

        case .notDetermined:
            guard !didRequestCameraAccess else {
                fallbackRoadView.isHidden = false
                return
            }

            didRequestCameraAccess = true
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }

                    if granted {
                        self.configureAndStartCameraSession()
                    } else {
                        self.fallbackRoadView.isHidden = false
                    }
                }
            }

        case .denied, .restricted:
            fallbackRoadView.isHidden = false

        @unknown default:
            fallbackRoadView.isHidden = false
        }
        #endif
    }

    private func configureAndStartCameraSession() {
        cameraSessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            if self.captureSession == nil {
                guard let session = self.makeCaptureSession() else {
                    DispatchQueue.main.async {
                        self.fallbackRoadView.isHidden = false
                    }
                    return
                }

                self.captureSession = session
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.videoGravity = .resizeAspectFill
                DispatchQueue.main.async {
                    self.previewLayer?.removeFromSuperlayer()
                    previewLayer.frame = self.livePreviewHost.bounds
                    self.livePreviewHost.layer.insertSublayer(previewLayer, at: 0)
                    self.previewLayer = previewLayer
                }
            }

            guard let captureSession = self.captureSession, !captureSession.isRunning else {
                DispatchQueue.main.async {
                    self.fallbackRoadView.isHidden = true
                }
                return
            }

            captureSession.startRunning()
            DispatchQueue.main.async {
                self.fallbackRoadView.isHidden = false
                self.previewLayer?.frame = self.livePreviewHost.bounds
                self.fallbackRoadView.isHidden = false
                self.fallbackRoadView.alpha = 0
                UIView.animate(withDuration: 0.18) {
                    self.fallbackRoadView.alpha = 0
                } completion: { _ in
                    self.fallbackRoadView.isHidden = true
                    self.fallbackRoadView.alpha = 1
                }
            }
        }
    }

    private func makeCaptureSession() -> AVCaptureSession? {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera)
        else {
            return nil
        }

        let captureSession = AVCaptureSession()
        captureSession.beginConfiguration()

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            captureSession.commitConfiguration()
            return nil
        }

        captureSession.sessionPreset = .high
        captureSession.commitConfiguration()
        return captureSession
    }

    private func stopCameraSession() {
        cameraSessionQueue.async { [weak self] in
            guard let captureSession = self?.captureSession, captureSession.isRunning else {
                return
            }

            captureSession.stopRunning()
        }
    }

    @objc private func backButtonTapped() {
        if let navigationController, navigationController.viewControllers.first !== self {
            navigationController.popViewController(animated: true)
            return
        }

        if presentingViewController != nil {
            dismiss(animated: true)
        }
    }

    @objc private func modeToggleButtonTapped() {
        previewMode = previewMode == .live ? .map : .live
        render(container.makeRoutePlannerViewModel().state)
    }

    @objc private func nextButtonTapped() {
        let state = container.makeRoutePlannerViewModel().state
        let orderedPlaces = orderedPlaces(for: state)
        let totalLegs = max(orderedPlaces.count - 1, 0)

        guard totalLegs > 0 else {
            showTripFlowScreen(withIdentifier: "TripSummaryViewController")
            return
        }

        if currentLegIndex < totalLegs - 1 {
            currentLegIndex += 1
            render(state)
            return
        }

        showTripFlowScreen(withIdentifier: "TripSummaryViewController")
    }

    private func orderedPlaces(for state: RoutePlannerViewModel.ViewState) -> [Place] {
        let snapshot = container.tripPlannerStore.snapshot
        guard !state.optimizedPlaces.isEmpty else {
            return snapshot.routingPlaces
        }

        let indexedPlaces = Dictionary(uniqueKeysWithValues: snapshot.routingPlaces.map { ($0.placeID, $0) })
        return state.optimizedPlaces.compactMap { indexedPlaces[$0] }
    }

    private func instructionStyle(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> InstructionStyle {
        let latitudeDelta = to.latitude - from.latitude
        let longitudeDelta = to.longitude - from.longitude

        if abs(longitudeDelta) > abs(latitudeDelta) * 0.75 {
            return longitudeDelta >= 0 ? .right : .left
        }

        return .straight
    }

    private func instructionTitle(for style: InstructionStyle, destination: String) -> String {
        switch style {
        case .left:
            return "Turn Left toward \(destination)"
        case .right:
            return "Turn Right toward \(destination)"
        case .straight:
            return "Continue to \(destination)"
        }
    }

    private func arrowDirection(for style: InstructionStyle) -> NavigationArrowOverlayView.Direction {
        switch style {
        case .left:
            return .left
        case .right:
            return .right
        case .straight:
            return .straight
        }
    }

    private func formattedDistance(_ meters: Int) -> String {
        if meters >= 1000 {
            let kilometers = Double(meters) / 1000
            return "\(kilometers.formatted(.number.precision(.fractionLength(1)))) km"
        }

        return "\(meters) meters"
    }

    private func distanceMeters(for state: RoutePlannerViewModel.ViewState, orderedPlaces: [Place], legIndex: Int) -> Int {
        if state.polylines.indices.contains(legIndex) {
            let coordinates = GooglePolylineDecoder.decode(state.polylines[legIndex])
            let distance = zip(coordinates, coordinates.dropFirst()).reduce(0.0) { partialResult, pair in
                let start = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                let end = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
                return partialResult + start.distance(from: end)
            }

            if distance > 0 {
                return max(Int(distance.rounded()), 50)
            }
        }

        guard orderedPlaces.indices.contains(legIndex + 1) else {
            return 50
        }

        let start = CLLocation(latitude: orderedPlaces[legIndex].latitude, longitude: orderedPlaces[legIndex].longitude)
        let end = CLLocation(latitude: orderedPlaces[legIndex + 1].latitude, longitude: orderedPlaces[legIndex + 1].longitude)
        return max(Int(start.distance(from: end).rounded()), 50)
    }

    private func estimatedSegmentMinutes(for state: RoutePlannerViewModel.ViewState, totalLegs: Int) -> Int {
        guard totalLegs > 0 else {
            return 0
        }

        let totalMinutes = state.totalTimeMinutes ?? (totalLegs * 12)
        return max(5, totalMinutes / totalLegs)
    }

    private func renderMap(for state: RoutePlannerViewModel.ViewState, snapshot: NavigationSnapshot?) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard let snapshot else {
            return
        }

        let overlays: [MKPolyline]
        if state.polylines.indices.contains(currentLegIndex) {
            let coordinates = GooglePolylineDecoder.decode(state.polylines[currentLegIndex])
            overlays = coordinates.count >= 2 ? [MKPolyline(coordinates: coordinates, count: coordinates.count)] : []
        } else {
            let coordinates = [snapshot.fromPlace.coordinate, snapshot.toPlace.coordinate]
            overlays = [MKPolyline(coordinates: coordinates, count: coordinates.count)]
        }

        if !overlays.isEmpty {
            mapView.addOverlays(overlays)
        }

        let annotations = snapshot.orderedPlaces.enumerated().compactMap { index, place -> RouteStopAnnotation? in
            let markerText: String
            let subtitle: String?

            if index == currentLegIndex {
                markerText = "S"
                subtitle = "Current Stop"
            } else if index == currentLegIndex + 1 {
                markerText = "N"
                subtitle = "Next Stop"
            } else {
                markerText = "\(index)"
                subtitle = "Stop \(index)"
            }

            return RouteStopAnnotation(
                coordinate: place.coordinate,
                title: place.name,
                subtitle: subtitle,
                markerText: markerText
            )
        }
        mapView.addAnnotations(annotations)

        if let overlay = overlays.first {
            mapView.setVisibleMapRect(
                overlay.boundingMapRect,
                edgePadding: UIEdgeInsets(top: 120, left: 30, bottom: 220, right: 30),
                animated: false
            )
        } else if !annotations.isEmpty {
            mapView.showAnnotations(annotations, animated: false)
        }
    }

    private func showTripFlowScreen(withIdentifier storyboardIdentifier: String) {
        let storyboard = UIStoryboard(name: "TripFlow", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: storyboardIdentifier)

        if let navigationController {
            navigationController.pushViewController(controller, animated: true)
            return
        }

        let modalNavigationController = UINavigationController(rootViewController: controller)
        modalNavigationController.modalPresentationStyle = .fullScreen
        present(modalNavigationController, animated: true)
    }
}

extension ARNavigationViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }

        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = UIColor(red: 0.22, green: 0.90, blue: 1.0, alpha: 0.95)
        renderer.lineWidth = 6
        renderer.lineCap = .round
        renderer.lineJoin = .round
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let routeAnnotation = annotation as? RouteStopAnnotation else {
            return nil
        }

        let reuseIdentifier = "ARNavigationRouteStopAnnotationView"
        let annotationView = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: routeAnnotation, reuseIdentifier: reuseIdentifier)

        annotationView.annotation = routeAnnotation
        annotationView.canShowCallout = true
        annotationView.glyphText = routeAnnotation.markerText
        annotationView.markerTintColor = routeAnnotation.markerText == "N" ? .systemTeal : .systemBlue
        return annotationView
    }
}
