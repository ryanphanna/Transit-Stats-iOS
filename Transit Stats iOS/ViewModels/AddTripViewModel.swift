import SwiftUI
import SwiftData
import CoreLocation
import FirebaseAuth
import Combine

@MainActor
class AddTripViewModel: ObservableObject {
    var modelContext: ModelContext?
    
    // Step 1: waiting at stop
    @Published var stopText = ""
    
    // OCR & Camera State
    @Published var showingImagePicker = false
    @Published var capturedImage: UIImage? = nil
    @Published var isProcessingOCR = false
    @Published var detectedRoutes: [String] = []
    @Published var detectedStops: [String] = []
    @Published var showingRoutePicker = false
    @Published var showingStopPicker = false
    
    @Published var isLocating = false

    // Step 2: boarded — enter route
    @Published var routeText = ""
    @Published var agency = "TTC"
    @Published var direction = ""

    @Published var step: BoardingStep = .atStop
    @Published var isLoading = false
    @Published var showingAdvancedOptions = false
    
    @Published var suggestions: [PredictionEngine.Prediction] = []

    // Timestamp when the user first taps "I'm at the stop"
    @Published var waitingSince: Date? = nil

    enum BoardingStep {
        case atStop, onBoard
    }

    private let authManager = AuthManager.shared
    private let locationManager = LocationManager.shared
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    func getNearbyHubs(stops: [Stop]) -> [NearbyHub] {
        guard let location = locationManager.lastLocation else { return [] }
        
        let nearbyStops = stops.filter { stop in
            let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
            return stopLocation.distance(from: location) < 500
        }
        
        var hubGroups: [String: [Stop]] = [:]
        for stop in nearbyStops {
            let key = stop.hubId ?? stop.id
            hubGroups[key, default: []].append(stop)
        }
        
        return hubGroups.map { key, stops in
            let bestStop = stops.first!
            let distance = CLLocation(latitude: bestStop.latitude, longitude: bestStop.longitude).distance(from: location)
            
            return NearbyHub(
                id: key,
                name: bestStop.name,
                isVerified: stops.contains(where: { $0.verified }),
                distance: distance,
                stops: stops
            )
        }
        .sorted { $0.distance < $1.distance }
    }

    func getStopSuggestions(tripHistory: [TripRecord], stops: [Stop]) -> [StopSuggestion] {
        let query = stopText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        
        var historyMatches: [String] = []
        var historySeen = Set<String>()
        for trip in tripHistory {
            if let name = trip.startStopName,
               name.lowercased().contains(query),
               !historySeen.contains(name.lowercased()) {
                historyMatches.append(name)
                historySeen.insert(name.lowercased())
            }
            if historyMatches.count >= 5 { break }
        }
        
        let libraryMatches = stops.filter { stop in
            stop.name.lowercased().contains(query) && !historySeen.contains(stop.name.lowercased())
        }
        .sorted { (s1, s2) -> Bool in
            if s1.verified != s2.verified {
                return s1.verified && !s2.verified
            }
            return (s1.lastUsed ?? Date.distantPast) > (s2.lastUsed ?? Date.distantPast)
        }
        
        var results: [StopSuggestion] = historyMatches.map { StopSuggestion(name: $0, isFromHistory: true, isVerified: false) }
        for stop in libraryMatches.prefix(5 - results.count) {
            results.append(StopSuggestion(name: stop.name, isFromHistory: false, isVerified: stop.verified))
        }
        return results
    }

    func processCapturedImage(_ image: UIImage) {
        isProcessingOCR = true
        VisionOCRManager.shared.processImage(image) { recognizedStrings in
            Task { @MainActor in
                let routes = VisionOCRManager.shared.extractRoutes(from: recognizedStrings)
                let stops = VisionOCRManager.shared.extractStopNames(from: recognizedStrings)
                self.isProcessingOCR = false
                
                self.detectedRoutes = routes
                self.detectedStops = stops
                
                if !routes.isEmpty {
                    self.showingRoutePicker = true
                } else if !stops.isEmpty {
                    self.showingStopPicker = true
                }
            }
        }
    }
    
    func selectNearbyHub(_ hub: NearbyHub) {
        stopText = hub.name
        // Potential: auto-select best stop from hub
    }
}

struct NearbyHub: Identifiable {
    let id: String
    let name: String
    let isVerified: Bool
    let distance: CLLocationDistance
    let stops: [Stop]
}

struct StopSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let isFromHistory: Bool
    let isVerified: Bool
}
