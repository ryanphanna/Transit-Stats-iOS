import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    var horizontalAccuracy: Double {
        lastLocation?.horizontalAccuracy ?? -1
    }
    
    /// Returns true if the GPS signal is "good" (< 65m accuracy)
    var isAccuracySufficient: Bool {
        let acc = horizontalAccuracy
        return acc > 0 && acc <= 65
    }
    
    /// Returns a human-readable description of signal quality
    var signalQuality: String {
        let acc = horizontalAccuracy
        if acc < 0 { return "No Signal" }
        if acc <= 30 { return "Excellent" }
        if acc <= 65 { return "Good" }
        if acc <= 150 { return "Fair (Poor GPS)" }
        return "Poor (Inaccurate)"
    }
    
    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        manager.startUpdatingLocation()
    }
    
    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.lastLocation = locations.last
    }
}
