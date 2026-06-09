import SwiftUI
import SwiftData
import CoreLocation
import FirebaseAuth

struct AddTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @EnvironmentObject private var appEnv: AppEnvironment
    private var accent: Color { appEnv.accent }

    @Query(sort: \TripRecord.startTime, order: .reverse) private var tripHistory: [TripRecord]
    @Query private var stops: [Stop]
    @Query private var profiles: [UserProfile]

    // Step 1: waiting at stop
    @State private var stopText = ""
    
    // OCR & Camera State
    @State private var showingImagePicker = false
    @State private var capturedImage: UIImage? = nil
    @State private var isProcessingOCR = false
    @State private var detectedRoutes: [String] = []
    @State private var detectedStops: [String] = []
    @State private var showingRoutePicker = false
    @State private var showingStopPicker = false
    
    private var profile: UserProfile? { profiles.first }
    
    @State private var isLocating = false

    private var nearbyHubs: [NearbyHub] {
        guard let location = locationManager.lastLocation else { return [] }
        
        // 1. Find all stops within 500m
        let nearbyStops = stops.filter { stop in
            let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
            return stopLocation.distance(from: location) < 500
        }
        
        // 2. Group by hubId (or id if no hubId)
        var hubGroups: [String: [Stop]] = [:]
        for stop in nearbyStops {
            let key = stop.hubId ?? stop.id
            hubGroups[key, default: []].append(stop)
        }
        
        // 3. Map to NearbyHub objects
        return hubGroups.map { key, stops in
            let bestStop = stops.first! // For now just take the one with the shortest distance ideally, or just first
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

    private var stopSuggestions: [StopSuggestion] {
        let query = stopText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        
        // Find matching stop names from trip history
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
        
        // Find matching stops from stop library
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

    // Step 2: boarded — enter route
    @State private var routeText = ""
    @State private var agency = "TTC"
    @State private var direction = ""

    @State private var step: BoardingStep = .atStop
    @State private var isLoading = false
    @State private var showingAdvancedOptions = false
    
    @State private var suggestions: [PredictionEngine.Prediction] = []

    // Timestamp when the user first taps "I'm at the stop"
    @State private var waitingSince: Date? = nil

    enum BoardingStep {
        case atStop, onBoard
    }

    let agencies = ["TTC", "GO", "UP Express", "VIA Rail", "YRT", "MiWay", "HSR"]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle + dismiss
                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 5)
                        .frame(maxWidth: .infinity)
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.45))
                                .padding(7)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 20)

                // Progress indicator
                HStack(spacing: 8) {
                    stepDot(label: "WAITING", active: step == .atStop, done: step == .onBoard)
                    Rectangle()
                        .fill(step == .onBoard ? accent : Color.white.opacity(0.12))
                        .frame(height: 1)
                        .animation(.easeInOut(duration: 0.4), value: step)
                    stepDot(label: "BOARDED", active: step == .onBoard, done: false)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

                // Step content
                Group {
                    if step == .atStop {
                        atStopView
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        onBoardView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: step)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
            
            // Set default agency from profile
            if let defaultAg = profile?.defaultAgency {
                self.agency = defaultAg
            }
        }
        .onDisappear {
            locationManager.stopUpdating()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $capturedImage)
        }
        .onChange(of: capturedImage) { _, newValue in
            if let image = newValue {
                processCapturedImage(image)
            }
        }
        .confirmationDialog("Select Route", isPresented: $showingRoutePicker, titleVisibility: .visible) {
            ForEach(detectedRoutes, id: \.self) { route in
                Button(route) {
                    routeText = route
                    submitTrip()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Multiple routes detected in the photo.")
        }
        .confirmationDialog("Select Stop", isPresented: $showingStopPicker, titleVisibility: .visible) {
            ForEach(detectedStops, id: \.self) { stop in
                Button(stop) {
                    stopText = stop
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Likely stop names found in the photo.")
        }
    }
    
    private func processCapturedImage(_ image: UIImage) {
        isProcessingOCR = true
        VisionOCRManager.shared.processImage(image) { recognizedStrings in
            DispatchQueue.main.async {
                let routes = VisionOCRManager.shared.extractRoutes(from: recognizedStrings)
                let stopNames = VisionOCRManager.shared.extractStopNames(from: recognizedStrings)
                self.isProcessingOCR = false
                
                // Handle Stop Names
                if stopNames.count == 1 && self.stopText.isEmpty {
                    self.stopText = stopNames[0]
                } else if stopNames.count > 1 && self.stopText.isEmpty {
                    self.detectedStops = stopNames
                    self.showingStopPicker = true
                }
                
                // Handle Routes
                if routes.count == 1 {
                    self.routeText = routes[0]
                    // If we found a route and a stop name was already set (or just found), start trip
                    if !self.stopText.isEmpty {
                        self.submitTrip()
                    }
                } else if routes.count > 1 {
                    self.detectedRoutes = routes
                    self.showingRoutePicker = true
                }
            }
        }
    }

    // MARK: - Step Views

    private var atStopView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Where are you waiting?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Optional — enter the stop you're at or leave blank.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.45))
                    .lineSpacing(2)
            }
            .padding(.horizontal, 28)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("STOP")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                        .kerning(1.2)
                        .padding(.horizontal, 28)

                    HStack(spacing: 10) {
                        ZStack(alignment: .trailing) {
                            TextField("e.g. College St at Spadina", text: $stopText)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .padding(.leading, 16)
                                .padding(.trailing, 44)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            stopText.isEmpty ? Color.white.opacity(0.1) : accent.opacity(0.4),
                                            lineWidth: 1
                                        )
                                )
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .onSubmit { startTripAtStop() }

                            if stopText.isEmpty {
                                Button(action: locateUser) {
                                    ZStack {
                                        if isLocating {
                                            ProgressView().tint(accent)
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(accent)
                                        }
                                    }
                                    .frame(width: 32, height: 32)
                                    .background(accent.opacity(0.15))
                                    .clipShape(Circle())
                                }
                                .padding(.trailing, 8)
                            } else {
                                Button(action: { stopText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.2))
                                }
                                .padding(.trailing, 12)
                            }
                        }
                        
                        Button(action: { showingImagePicker = true }) {
                            ZStack {
                                if isProcessingOCR {
                                    ProgressView().tint(accent)
                                } else {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 20))
                                        .foregroundColor(accent)
                                }
                            }
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .disabled(isProcessingOCR)
                    }
                    .padding(.horizontal, 20)
                }

                // Stop suggestions / Nearby stop/hub suggestions
                if !stopText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let suggestions = stopSuggestions
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(suggestions) { suggestion in
                                Button(action: {
                                    stopText = suggestion.name
                                    startTripAtStop()
                                }) {
                                    HStack(spacing: 10) {
                                        if suggestion.isFromHistory {
                                            Image(systemName: "clock")
                                                .font(.system(size: 12))
                                                .foregroundColor(.blue)
                                        } else if suggestion.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.blue)
                                        } else {
                                            Image(systemName: "mappin.and.ellipse")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        
                                        Text(suggestion.name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                } else {
                    // NEARBY SECTION
                    VStack(alignment: .leading, spacing: 10) {
                        if !nearbyHubs.isEmpty {
                            HStack {
                                Text("NEARBY STOPS")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(Color.white.opacity(0.35))
                                    .kerning(1.2)
                                Spacer()
                            }
                            .padding(.horizontal, 28)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(nearbyHubs.prefix(5)) { hub in
                                        Button(action: {
                                            withAnimation(.spring()) {
                                                stopText = hub.name
                                            }
                                        }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: hub.isVerified ? "checkmark.seal.fill" : "mappin.and.ellipse")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(hub.isVerified ? .blue : .white.opacity(0.6))
                                                    Text("\(Int(hub.distance))m away")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .foregroundColor(.white.opacity(0.3))
                                                }
                                                
                                                Text(hub.name)
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.white.opacity(0.08))
                                            .cornerRadius(14)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(hub.isVerified ? Color.blue.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        } else if isLocating {
                            HStack(spacing: 12) {
                                ProgressView().tint(.blue)
                                Text("Finding nearby stops...")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                        }
                    }
                }

            }

            // Primary CTA
            Button(action: startTripAtStop) {
                HStack {
                    Spacer()
                    Text("Continue")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [accent, .brandBlue], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 20)
        }
    }

    private var onBoardView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)
                    Text("YOU'RE ON BOARD!")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(accent)
                        .kerning(1.5)
                }

                Text("Which route did you board?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 2)

                if !stopText.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.35))
                        Text(stopText)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                }
            }
            .padding(.horizontal, 28)

            VStack(spacing: 14) {
                // Route input
                VStack(alignment: .leading, spacing: 8) {
                    Text("ROUTE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                        .kerning(1.2)
                        .padding(.horizontal, 28)

                    HStack(spacing: 12) {
                        TextField("e.g. 506, Line 1, GO Lakeshore", text: $routeText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        routeText.isEmpty ? Color.white.opacity(0.1) : accent.opacity(0.5),
                                        lineWidth: 1
                                    )
                            )
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { if !routeText.isEmpty { submitTrip() } }
                        
                        Button(action: { showingImagePicker = true }) {
                            ZStack {
                                if isProcessingOCR {
                                    ProgressView().tint(accent)
                                } else {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 20))
                                        .foregroundColor(accent)
                                }
                            }
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .disabled(isProcessingOCR)
                    }
                    .padding(.horizontal, 20)
                }

                // Route suggestions based on history
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SUGGESTED FOR THIS STOP")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.3))
                            .kerning(1)
                            .padding(.horizontal, 28)
                            
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(suggestions, id: \.route) { pred in
                                    Button(action: {
                                        routeText = pred.route
                                        direction = pred.direction
                                        if let match = tripHistory.first(where: { $0.route == pred.route }) {
                                            agency = match.agency
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(pred.route)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(routeText == pred.route ? .white : .orange)
                                            
                                            if !pred.direction.isEmpty {
                                                Text(pred.direction.uppercased())
                                                    .font(.system(size: 8, weight: .black))
                                                    .foregroundColor(routeText == pred.route ? .white.opacity(0.8) : .white.opacity(0.4))
                                                    .kerning(0.5)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(routeText == pred.route ? accent : Color.white.opacity(0.08))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(routeText == pred.route ? Color.clear : Color.white.opacity(0.05), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // Inline Direction Suggestions (visible when route is selected/typed and matches exist)
                if !routeText.isEmpty {
                    let dirPredictions = PredictionEngine.predict(history: tripHistory, stopName: stopText)
                        .filter { $0.route == routeText }
                    
                    if !dirPredictions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DIRECTION")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.35))
                                .kerning(1.2)
                                .padding(.horizontal, 28)
                                
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(dirPredictions, id: \.direction) { pred in
                                        Button(action: { direction = pred.direction }) {
                                            Text(pred.direction)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(direction == pred.direction ? accent : Color.white.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                // Advanced Options Toggle
                Button(action: { withAnimation { showingAdvancedOptions.toggle() } }) {
                    HStack {
                        Text(showingAdvancedOptions ? "Hide Details" : "Add Agency")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: showingAdvancedOptions ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)

                if showingAdvancedOptions {
                    VStack(spacing: 16) {
                        // Agency picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AGENCY")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.35))
                                .kerning(1.2)
                                .padding(.horizontal, 28)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(agencies, id: \.self) { ag in
                                        Button(action: { agency = ag }) {
                                            Text(ag)
                                                .font(.system(size: 11, weight: .semibold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(agency == ag ? accent : Color.white.opacity(0.07))
                                                .foregroundColor(agency == ag ? .white : Color.white.opacity(0.5))
                                                .cornerRadius(20)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(agency == ag ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }

            // Start Trip CTA
            Button(action: submitTrip) {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 14))
                        Text("START TRIP")
                            .font(.system(size: 13, weight: .black))
                            .kerning(1)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(
                    routeText.isEmpty
                        ? AnyShapeStyle(Color.white.opacity(0.06))
                        : AnyShapeStyle(LinearGradient(colors: [accent, .brandBlue], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(routeText.isEmpty ? Color.white.opacity(0.25) : .white)
                .cornerRadius(14)
                .shadow(color: routeText.isEmpty ? .clear : Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(isLoading || routeText.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.2), value: routeText.isEmpty)

            // Back button
            Button(action: { withAnimation { step = .atStop } }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11))
                    Text("Back to Stop")
                        .font(.system(size: 12))
                }
                .foregroundColor(Color.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    // MARK: - Step Indicator

    private func stepDot(label: String, active: Bool, done: Bool) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(done || active ? accent : Color.white.opacity(0.1))
                    .frame(width: 10, height: 10)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 6, weight: .black))
                        .foregroundColor(.white)
                }
            }
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(active ? .orange : Color.white.opacity(0.3))
                .kerning(0.8)
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Actions

    private func locateUser() {
        isLocating = true
        locationManager.requestPermission()
        locationManager.startUpdating()
        
        // Give it a second to find location
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLocating = false
        }
    }

    private func startTripAtStop() {
        let stop = stopText.trimmingCharacters(in: .whitespaces)
        guard !stop.isEmpty else { return }
        
        guard let userId = authManager.currentUser?.uid else {
            print("Error: No user logged in")
            return
        }

        isLoading = true

        let location = locationManager.lastLocation
        let useLocation = locationManager.isAccuracySufficient

        let newTrip = TripRecord(
            route: "",
            direction: "",
            agency: agency,
            startTime: Date(),
            startStopName: stop,
            startLatitude: useLocation ? location?.coordinate.latitude : nil,
            startLongitude: useLocation ? location?.coordinate.longitude : nil,
            startAccuracy: useLocation ? location?.horizontalAccuracy : nil,
            userId: userId,
            isSynced: false
        )

        modelContext.insert(newTrip)

        do {
            try modelContext.save()
            locationManager.startPathTracking()
            isLoading = false
            dismiss()
        } catch {
            print("Failed to save local trip: \(error.localizedDescription)")
            isLoading = false
        }
    }

    private func submitTrip() {
        let route = routeText.trimmingCharacters(in: .whitespaces)
        guard !route.isEmpty else { return }
        
        guard let userId = authManager.currentUser?.uid else {
            print("Error: No user logged in")
            return
        }

        isLoading = true

        let stop = stopText.trimmingCharacters(in: .whitespaces)
        
        let location = locationManager.lastLocation
        let useLocation = locationManager.isAccuracySufficient
        
        let newTrip = TripRecord(
            route: route,
            direction: direction,
            agency: agency,
            startTime: Date(),
            startStopName: stop.isEmpty ? nil : stop,
            startLatitude: useLocation ? location?.coordinate.latitude : nil,
            startLongitude: useLocation ? location?.coordinate.longitude : nil,
            startAccuracy: useLocation ? location?.horizontalAccuracy : nil,
            userId: userId,
            isSynced: false
        )
        
        modelContext.insert(newTrip)
        
        do {
            try modelContext.save()
            locationManager.startPathTracking()
            isLoading = false
            dismiss()
        } catch {
            print("Failed to save local trip: \(error.localizedDescription)")
            isLoading = false
        }
    }
}

// MARK: - Support Types

struct NearbyHub: Identifiable {
    let id: String
    let name: String
    let isVerified: Bool
    let distance: Double
    let stops: [Stop]
}

struct StopSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let isFromHistory: Bool
    let isVerified: Bool
}
