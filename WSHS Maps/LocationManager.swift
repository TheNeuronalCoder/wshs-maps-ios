//
//  LocationManager.swift
//  WSHS Maps
//
//  Created by Menelik Eyasu on 7/17/22.
//

import Combine
import Foundation
import CoreLocation
import CoreGraphics

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var metadata: [Int: Metadata] = [:]
    private let locationManager = CLLocationManager()

    @Published var updates: Int = 0
    @Published var initialized: Bool = false
    @Published var access: String = "unknown"

    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    
    @Published var x: Double = 0
    @Published var y: Double = 0
    @Published var z: Int = 2

    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
    }

    func set_metadata(floors: [Int: Floor]) {
        if let floor1 = floors[1] {
            self.metadata[1] = floor1.metadata
        }
        if let floor2 = floors[2] {
            self.metadata[2] = floor2.metadata
        }
        if let floor3 = floors[3] {
            self.metadata[3] = floor3.metadata
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
            case .notDetermined: access = "notDetermined"
            case .authorizedWhenInUse: access = "authorizedWhenInUse"
            case .authorizedAlways: access = "authorizedAlways"
            case .restricted: access = "restricted"
            case .denied: access = "denied"
            default: access = "unknown"
        }
        
        if !access.hasPrefix("authorized") {
            self.initialized = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude

        self.update_position(
            lat: location.coordinate.latitude,
            long: location.coordinate.longitude,
            z: self.z
        )

        if self.x > 0 && self.y > 0 {
            self.initialized = true
        }
    }

    func update_position(lat: Double, long: Double, z: Int) {
        if let metadata = self.metadata[z] {
            let a = metadata.orientation.angle*Double.pi/180
            let proj_x = (long-metadata.orientation.origin[1])/metadata.orientation.scale[0]
            let proj_y = (metadata.orientation.origin[0]-lat)/metadata.orientation.scale[1]
            let p = CGPoint(
                x: proj_x * cos(a) + proj_y * sin(a),
                y: proj_y * cos(a) - proj_x * sin(a)
            )

            let rp = metadata.hallways.reduce([0, 0, Double.infinity], { closest, hall in
                let atob = [hall[2]-hall[0], hall[3]-hall[1]]
                let atop = [p.x-hall[0], p.y-hall[1]]
                let len = atob[0]*atob[0]+atob[1]*atob[1]
                var dot = atop[0]*atob[0]+atop[1]*atob[1]
                let t = min(1, max(0, dot/len))
                dot = (hall[2]-hall[0])*(p.y-hall[1])-(hall[3]-hall[1])*(p.x-hall[0])
                let new_p = CGPoint(x: hall[0]+atob[0]*t, y: hall[1]+atob[1]*t)
                let new_p_dist = hypot(new_p.x-p.x, new_p.y-p.y)

                if new_p_dist < closest[2] {
                    return [new_p.x, new_p.y, new_p_dist]
                }
                return closest
            })
            self.x = rp[0]
            self.y = rp[1]
            self.z = z
            self.updates += 1
        }
    }
}
