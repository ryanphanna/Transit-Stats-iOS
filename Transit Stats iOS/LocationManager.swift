import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    // Path Tracking
    @Published var currentPath: [TripPathPoint] = []
    @Published var isTrackingPath = false
    
    // Toggle for High Fidelity (Admins only in UI)
    @Published var isHighFidelityEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHighFidelityEnabled, forKey: "isHighFidelityLocationEnabled")
        }
    }
    
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
    
    /// Returns true only if UIBackgroundModes includes "location" in the app's Info.plist.
    /// Setting allowsBackgroundLocationUpdates = true without this registered causes an
    /// EXC_BREAKPOINT assertion trap at runtime (not catchable with try/catch).
    private var backgroundLocationEnabled: Bool {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        return modes.contains("location")
    }

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        self.isHighFidelityEnabled = UserDefaults.standard.bool(forKey: "isHighFidelityLocationEnabled")
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // Only update every 10 meters to save battery
        manager.allowsBackgroundLocationUpdates = backgroundLocationEnabled
        manager.pausesLocationUpdatesAutomatically = true
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        manager.startUpdatingLocation()
    }
    
    func stopUpdating() {
        if !isTrackingPath {
            manager.stopUpdatingLocation()
        }
    }
    
    func startPathTracking() {
        currentPath = []
        isTrackingPath = true
        manager.startUpdatingLocation()
        if backgroundLocationEnabled {
            manager.allowsBackgroundLocationUpdates = true
        }
    }
    
    func stopPathTracking() -> Data? {
        isTrackingPath = false
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
        
        let path = currentPath
        currentPath = []
        
        return try? JSONEncoder().encode(path)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.lastLocation = locations.last
        
        if isTrackingPath, let location = locations.last, isHighFidelityEnabled {
            // Only add if accuracy is good
            if location.horizontalAccuracy <= 65 {
                let point = TripPathPoint(
                    lat: location.coordinate.latitude,
                    lon: location.coordinate.longitude,
                    timestamp: location.timestamp,
                    speed: location.speed >= 0 ? location.speed : nil
                )
                currentPath.append(point)
            }
        }
    }
}
