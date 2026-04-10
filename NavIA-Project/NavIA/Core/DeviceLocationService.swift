//
//  DeviceLocationService.swift
//  NavIA
//

import CoreLocation
import Foundation

protocol DeviceLocationProviding: AnyObject {
    var lastKnownCoordinate: CLLocationCoordinate2D? { get }
    func requestCurrentLocation(completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void)
}

enum DeviceLocationError: LocalizedError {
    case servicesDisabled
    case denied
    case unavailable
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            return "Location Services are disabled on this device."
        case .denied:
            return "Location access was denied. Enable While Using the App in iOS Settings to start routes from the current device location."
        case .unavailable:
            return "Current location is temporarily unavailable."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

final class DeviceLocationService: NSObject, DeviceLocationProviding {
    static let shared = DeviceLocationService()

    private let locationManager = CLLocationManager()
    private var completions: [(Result<CLLocationCoordinate2D, Error>) -> Void] = []

    private(set) var lastKnownCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestCurrentLocation(completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        guard CLLocationManager.locationServicesEnabled() else {
            completion(.failure(DeviceLocationError.servicesDisabled))
            return
        }

        if let lastKnownCoordinate {
            completion(.success(lastKnownCoordinate))
            return
        }

        completions.append(completion)

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()

        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .denied, .restricted:
            finishPendingRequests(with: .failure(DeviceLocationError.denied))

        @unknown default:
            finishPendingRequests(with: .failure(DeviceLocationError.unavailable))
        }
    }

    private func finishPendingRequests(with result: Result<CLLocationCoordinate2D, Error>) {
        let handlers = completions
        completions.removeAll()
        handlers.forEach { $0(result) }
    }
}

extension DeviceLocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()

        case .denied, .restricted:
            finishPendingRequests(with: .failure(DeviceLocationError.denied))

        case .notDetermined:
            break

        @unknown default:
            finishPendingRequests(with: .failure(DeviceLocationError.unavailable))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            finishPendingRequests(with: .failure(DeviceLocationError.unavailable))
            return
        }

        lastKnownCoordinate = coordinate
        finishPendingRequests(with: .success(coordinate))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let coordinate = manager.location?.coordinate {
            lastKnownCoordinate = coordinate
            finishPendingRequests(with: .success(coordinate))
            return
        }

        finishPendingRequests(with: .failure(DeviceLocationError.underlying(error)))
    }
}
