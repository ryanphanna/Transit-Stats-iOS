import SwiftUI
import SwiftData
import Combine
import MapKit
import FirebaseAuth

@MainActor
class HomeViewModel: ObservableObject {
    var modelContext: ModelContext?
    
    @Published var endStopText = ""
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var isShowingAddTripSheet = false
    @Published var isShowingSettingsSheet = false
    @Published var activeRouteText = ""

    // Panel State
    let snapHeights: [CGFloat] = [140, 380, 620]
    @Published var panelHeight: CGFloat = 380
    @Published var dragOffset: CGFloat = 0
    
    var effectivePanelHeight: CGFloat {
        max(snapHeights[0], panelHeight + dragOffset)
    }

    // Map State
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var pendingLocationZoom = false
    
    // Live timer trigger
    @Published var timeElapsed = ""
    
    private let tripService = TripService.shared
    private let locationManager = LocationManager.shared
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }
    
    func updateTimer(for trip: TripRecord) {
        let diff = Date().timeIntervalSince(trip.startTime)
        let mins = Int(diff / 60)
        if mins < 1 {
            timeElapsed = "0 min"
        } else {
            timeElapsed = "\(mins) min"
        }
    }

    func startShortcut(_ shortcut: ShortcutOption, userId: String?) {
        guard let userId = userId else { return }

        let location = locationManager.lastLocation
        let useLocation = locationManager.isAccuracySufficient

        let newTrip = TripRecord(
            route: shortcut.route,
            direction: shortcut.direction,
            agency: "TTC", // Default for shortcuts
            startTime: Date(),
            startStopName: shortcut.stopName,
            startLatitude: useLocation ? location?.coordinate.latitude : nil,
            startLongitude: useLocation ? location?.coordinate.longitude : nil,
            startAccuracy: useLocation ? location?.horizontalAccuracy : nil,
            userId: userId,
            isSynced: false
        )

        modelContext?.insert(newTrip)
        try? modelContext?.save()

        locationManager.startPathTracking()
    }

    func endTrip(activeTrip: TripRecord?) {
        guard let trip = activeTrip else { return }

        let stop = endStopText.trimmingCharacters(in: .whitespaces)
        trip.endStopName = stop.isEmpty ? nil : stop
        trip.endTime = Date()

        if locationManager.isAccuracySufficient, let location = locationManager.lastLocation {
            trip.endLatitude = location.coordinate.latitude
            trip.endLongitude = location.coordinate.longitude
            trip.endAccuracy = location.horizontalAccuracy
        }

        trip.pathData = locationManager.stopPathTracking()

        try? modelContext?.save()
        
        let tripToSync = trip
        endStopText = ""
        
        Task {
            do {
                try await tripService.uploadTrip(tripToSync)
                try? modelContext?.save()
            } catch {
                print("Failed to sync completed trip: \(error.localizedDescription)")
            }
        }
    }
    
    func forgotTrip(activeTrip: TripRecord?) {
        guard let trip = activeTrip else { return }
        
        trip.endTime = trip.startTime.addingTimeInterval(15 * 60)
        trip.notes = (trip.notes ?? "") + " (Flagged as forgotten)"
        
        try? modelContext?.save()
        
        let tripToSync = trip
        Task {
            try? await tripService.uploadTrip(tripToSync)
            try? modelContext?.save()
        }
    }
    
    func discardTrip(activeTrip: TripRecord?) {
        guard let trip = activeTrip else { return }
        modelContext?.delete(trip)
        try? modelContext?.save()
    }

    func updateCameraPosition(mapMarkers: [TripMarker]) {
        if let coord = locationManager.lastLocation?.coordinate {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            ))
            return
        }
        
        let recent = Array(mapMarkers.sorted { $0.count > $1.count }.prefix(10))
        guard !recent.isEmpty else { return }
        let coordinates = recent.map { $0.coordinate }
        var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
        for coord in coordinates {
            minLat = min(minLat, coord.latitude); maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude); maxLon = max(maxLon, coord.longitude)
        }
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.05),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.05)
        )
        cameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: span
        ))
    }
    
    func handleLocationChange(_ location: CLLocation?) {
        guard pendingLocationZoom, let coord = location?.coordinate else { return }
        pendingLocationZoom = false
        withAnimation(.spring()) {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))
        }
    }

    func getShortcutOptions(completedTrips: [TripRecord]) -> [ShortcutOption] {
        let predictions = PredictionEngine.predict(history: completedTrips, stopName: nil)
        
        var options: [ShortcutOption] = []
        var seen = Set<String>()
        
        for prediction in predictions {
            if let trip = completedTrips.first(where: { 
                $0.route == prediction.route && $0.direction == prediction.direction 
            }) {
                guard let stopName = trip.startStopName ?? trip.startStopCode else { continue }
                let key = "\(prediction.route)|\(stopName)|\(prediction.direction)"
                
                if !seen.contains(key) {
                    seen.insert(key)
                    let command = "\(prediction.route) \(stopName) \(prediction.direction)".trimmingCharacters(in: .whitespaces)
                    options.append(ShortcutOption(
                        route: prediction.route,
                        stopName: stopName,
                        direction: prediction.direction,
                        command: command
                    ))
                }
            }
            if options.count >= 4 { break }
        }
        return options
    }
    
    func generateMapMarkers(completedTrips: [TripRecord], stopsLibrary: [Stop], hubsLibrary: [Hub], activeTrip: TripRecord?) -> [TripMarker] {
        var hubs: [String: (lat: Double, lon: Double, count: Int, route: String)] = [:]

        for trip in completedTrips {
            guard let name = trip.startStopName ?? trip.startStopCode else { continue }

            let lat: Double
            let lon: Double
            if let tLat = trip.startLatitude, let tLon = trip.startLongitude,
               trip.startAccuracy.map({ $0 <= 65 }) ?? true {
                lat = tLat; lon = tLon
            } else if let stop = stopsLibrary.first(where: {
                $0.code == trip.startStopCode || $0.name == trip.startStopName
            }) {
                lat = stop.latitude; lon = stop.longitude
            } else {
                continue
            }

            if var existing = hubs[name] {
                existing.count += 1
                hubs[name] = existing
            } else {
                hubs[name] = (lat: lat, lon: lon, count: 1, route: trip.route)
            }
        }
        
        var markers: [TripMarker] = hubs.map { name, data in
            let hubName = hubsLibrary.first(where: { $0.id == name })?.name ?? name
            
            return TripMarker(
                id: name,
                coordinate: CLLocationCoordinate2D(latitude: data.lat, longitude: data.lon),
                count: data.count,
                label: hubName,
                route: data.route
            )
        }
        
        if let trip = activeTrip, let lat = trip.startLatitude, let lon = trip.startLongitude {
            let name = trip.startStopName ?? trip.startStopCode ?? "Active"
            markers.append(TripMarker(
                id: "active",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                count: 1,
                label: name,
                route: trip.route,
                isActive: true
            ))
        }
        
        return markers
    }
}

struct ShortcutOption {
    let route: String
    let stopName: String
    let direction: String
    let command: String
}
