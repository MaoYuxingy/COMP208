//
//  ViewController.swift
//  NavIA
//
//  Created by 万俟修杰 on 2026/3/6.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.text = "Status: Ready"
        distanceLabel.text = "Distance: -"
        timeLabel.text = "Time: -"
    }
    
    @IBAction func optimizeRouteButtonTapped(_ sender: UIButton) {
        statusLabel.text = "Status: Loading..."
        
        let tripInfo = TripInfo(
            trip_id: "trip001",
            user_id: "user001",
            title: "Liverpool Trip",
            total_available_time: 480,
            created_at: "2026-03-06T11:34:18.764Z"
        )
        
        let places = [
            Place(
                place_id: "p1",
                name: "Museum",
                latitude: 53.406,
                longitude: -2.966,
                cached: false,
                visit_duration_minutes: 60
            ),
            Place(
                place_id: "p2",
                name: "Cathedral",
                latitude: 53.397,
                longitude: -2.971,
                cached: false,
                visit_duration_minutes: 45
            )
        ]
        
        let request = RouteRequest(
            trip_info: tripInfo,
            places_to_visit: places
        )
        
        APIService.shared.optimizeRoute(request: request) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.statusLabel.text = "Status: \(response.status)"
                    self.distanceLabel.text = "Distance: \(response.total_distance_km) km"
                    self.timeLabel.text = "Time: \(response.total_time_minutes) min"
                    
                case .failure(let error):
                    self.statusLabel.text = "Status: Failed"
                    self.distanceLabel.text = "Distance: -"
                    self.timeLabel.text = "Time: -"
                    print("Error: \(error)")
                }
            }
        }
    }
}
