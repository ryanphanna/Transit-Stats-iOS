import SwiftUI
import SwiftData
import Combine
import MapKit

// Simple Line shape helper for the timeline connection
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TripRecord> { $0.endTime == nil }, sort: \TripRecord.startTime, order: .reverse)
    private var activeTrips: [TripRecord]
    
    @Query(sort: \TripRecord.startTime, order: .reverse)
    private var completedTrips: [TripRecord]
    
    @StateObject private var api = TransitStatsAPI.shared
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var endStopText = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isShowingAddTripSheet = false
    @State private var isShowingSettingsSheet = false
    
    // Map State
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    private var mapMarkers: [TripMarker] {
        var hubs: [String: (lat: Double, lon: Double, count: Int, route: String)] = [:]
        
        // Group all completed trips into hubs by stop name
        for trip in completedTrips {
            guard let name = trip.startStopName ?? trip.startStopCode,
                  let lat = trip.startLatitude,
                  let lon = trip.startLongitude else { continue }
            
            // Background GPS validation: Skip inaccurate data (> 65m) for map visualization
            if let accuracy = trip.startAccuracy, accuracy > 65 { continue }
            
            if var existing = hubs[name] {
                existing.count += 1
                hubs[name] = existing
            } else {
                hubs[name] = (lat: lat, lon: lon, count: 1, route: trip.route)
            }
        }
        
        var markers: [TripMarker] = hubs.map { name, data in
            TripMarker(
                id: name,
                coordinate: CLLocationCoordinate2D(latitude: data.lat, longitude: data.lon),
                count: data.count,
                label: name,
                route: data.route
            )
        }
        
        // Add active trip if exists
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
    
    // Live timer trigger
    @State private var timeElapsed = ""
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    var activeTrip: TripRecord? {
        activeTrips.first
    }
    
    var body: some View {
        ZStack {
            // Full Screen Interactive Map Background
            Map(position: $cameraPosition) {
                ForEach(mapMarkers) { marker in
                    Annotation(marker.label, coordinate: marker.coordinate) {
                        HubView(marker: marker)
                    }
                }
                
                UserAnnotation()
            }
            .mapStyle(.standard(emphasis: .low, pointsOfInterest: .excludingAll))
            .onAppear {
                updateCameraPosition()
            }
            .onChange(of: mapMarkers.count) {
                withAnimation(.spring()) {
                    updateCameraPosition()
                }
            }
            .ignoresSafeArea()
            
            VStack {
                // Top floating UI containing custom liquid glass controls
                HStack {
                    Spacer()
                    
                    // Glassmorphic / Liquid Glass Control Bar
                    HStack(spacing: 16) {
                        Button(action: { isShowingProfileSheet = true }) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Divider()
                            .frame(height: 20)
                            .background(Color.white.opacity(0.2))
                        
                        Button(action: { isShowingAddTripSheet = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        
                        Divider()
                            .frame(height: 20)
                            .background(Color.white.opacity(0.2))
                        
                        Button(action: { isShowingSettingsSheet = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                Spacer()
                
                // Bottom sliding control drawer (Frosted Glass Panel)
                VStack(spacing: 12) {
                    // Pill drag handle indicator
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            
                            // Active Trip Panel or Ready State
                            if let trip = activeTrip {
                                activeTripCard(trip)
                                    .onAppear { updateTimer(for: trip) }
                                    .onReceive(timer) { _ in updateTimer(for: trip) }
                            } else {
                                readyStateCard
                            }
                            
                            // API Response Panel
                            if !api.lastReplies.isEmpty {
                                repliesPanel
                            }
                            
                            // Quick Shortcuts (derived from recent trips)
                            shortcutsSection
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 16)
                    }
                    .frame(maxHeight: 360)
                }
                .padding(.horizontal)
                .background(.ultraThinMaterial)
                .cornerRadius(30)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 15, x: 0, y: -5)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
        }
        .onDisappear {
            locationManager.stopUpdating()
        }
        .sheet(isPresented: $isShowingAddTripSheet) {
            AddTripView()
        .sheet(isPresented: $isShowingSettingsSheet) {
            SettingsView()
        }
        .sheet(isPresented: $isShowingProfileSheet) {
            ProfileView()
        }
        }

        .alert("API Error", isPresented: Binding(
            get: { api.lastError != nil },
            set: { if !$0 { api.lastError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(api.lastError ?? "")
        }
    }
    
    // MARK: - Views
    
    private func activeTripCard(_ trip: TripRecord) -> some View {
        VStack(spacing: 18) {
            // Status Row (App in the Air uppercase bold style)
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("IN TRANSIT")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.orange)
                        .kerning(1.5)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(4)
                
                Spacer()
                
                Text(trip.agency.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .kerning(1)
            }
            
            // Route Header Board
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.route)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    if !trip.direction.isEmpty {
                        Text(trip.direction.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                            .kerning(0.8)
                    }
                }
                Spacer()
            }
            
            // Boarding Pass / Travel Timeline
            HStack(spacing: 12) {
                // Origin Stop
                VStack(alignment: .leading, spacing: 4) {
                    Text("BOARDED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                        .kerning(1)
                    Text(trip.startStopName ?? trip.startStopCode ?? "Unknown stop")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Flight/Trip Timeline Connection Graphic
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 5, height: 5)
                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3]))
                        .frame(height: 1)
                        .foregroundColor(.blue.opacity(0.4))
                    Image(systemName: "tram.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3]))
                        .frame(height: 1)
                        .foregroundColor(.blue.opacity(0.4))
                    Circle().fill(Color.white.opacity(0.3)).frame(width: 5, height: 5)
                }
                .frame(width: 70)
                
                // Destination Stop (Pending input)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("DESTINATION")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                        .kerning(1)
                    Text(endStopText.isEmpty ? "SELECT EXIT" : endStopText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(endStopText.isEmpty ? .gray : .white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 6)
            
            // Duration Status Panel
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TIME ELAPSED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                        .kerning(1)
                    Text(timeElapsed.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
                Spacer()
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            // End trip input & buttons
            VStack(spacing: 12) {
                TextField("Enter Exit Stop Code or Name", text: $endStopText)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                HStack(spacing: 12) {
                    Button(action: endTrip) {
                        HStack {
                            Spacer()
                            if api.isSendingCommand {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("COMPLETE JOURNEY")
                                    .font(.system(size: 12, weight: .bold))
                                    .kerning(0.8)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color.orange.opacity(0.25), radius: 6, x: 0, y: 3)
                    }
                    .disabled(api.isSendingCommand)
                    
                    Menu {
                        Button("Forgot to End", role: .none, action: forgotTrip)
                        Button("Discard Trip", role: .destructive, action: discardTrip)
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(hex: "0d1527").opacity(0.9))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var readyStateCard: some View {
        VStack(spacing: 18) {
            // Flight Board Style Status Line
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                    Text("NO ACTIVE TRIP")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.gray)
                        .kerning(1.5)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(4)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Ready to go?")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Tap below when you're heading to your stop.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: { isShowingAddTripSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 12))
                    Text("Start Trip")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(LinearGradient(colors: [Color.orange, Color(hex: "ff6b35")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(color: Color.orange.opacity(0.25), radius: 8, x: 0, y: 4)
            }
        }
        .padding(20)
        .background(Color(hex: "0d1527").opacity(0.9))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    private var repliesPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NETWORK UPDATE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)
                    .kerning(1)
                Spacer()
                Button(action: { api.lastReplies = [] }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.footnote)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(api.lastReplies, id: \.self) { reply in
                    Text(reply)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 1)
                }
            }
            .padding(10)
            .background(Color.blue.opacity(0.12))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT SHORTCUTS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
                .kerning(1)
            
            // Extract top unique route/stop combinations from completed trips
            let shortcuts = getShortcutOptions()
            
            if shortcuts.isEmpty {
            Text("Your regular routes will appear here once you log a few trips.")
            .font(.system(size: 11))
            .foregroundColor(.gray)
            .padding(.top, 2)
            } else {
            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(shortcuts, id: \.command) { shortcut in
                    Button(action: { startShortcut(shortcut) }) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(shortcut.route)
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)

                            Text(shortcut.stopName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if !shortcut.direction.isEmpty {
                                Text(shortcut.direction.uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(12)
                        .frame(width: 125, alignment: .leading)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
            }
            }
            }
            }

            // MARK: - Actions

            private func updateTimer(for trip: TripRecord) {
            let diff = Date().timeIntervalSince(trip.startTime)
            let mins = Int(diff / 60)
            if mins < 1 {
            timeElapsed = "0 min"
            } else {
            timeElapsed = "\(mins) min"
            }
            }

            private func startShortcut(_ shortcut: ShortcutOption) {
                guard let userId = AuthManager.shared.currentUser?.uid else { return }

                let location = locationManager.lastLocation
                let useLocation = locationManager.isAccuracySufficient

                let newTrip = TripRecord(
                    route: shortcut.route,
                    direction: shortcut.direction,
                    agency: "TTC", // Default for shortcuts for now, could be stored in ShortcutOption
                    startTime: Date(),
                    startStopName: shortcut.stopName,
                    startLatitude: useLocation ? location?.coordinate.latitude : nil,
                    startLongitude: useLocation ? location?.coordinate.longitude : nil,
                    startAccuracy: useLocation ? location?.horizontalAccuracy : nil,
                    userId: userId,
                    isSynced: false
                )

                modelContext.insert(newTrip)
                try? modelContext.save()
            }

            private func endTrip() {
                guard let trip = activeTrip else { return }

                let stop = endStopText.trimmingCharacters(in: .whitespaces)
                trip.endStopName = stop.isEmpty ? nil : stop
                trip.endTime = Date()

                if locationManager.isAccuracySufficient, let location = locationManager.lastLocation {
                    trip.endLatitude = location.coordinate.latitude
                    trip.endLongitude = location.coordinate.longitude
                    trip.endAccuracy = location.horizontalAccuracy
                }

                // Save locally first
                try? modelContext.save()


        
        // Clear UI
        let tripToSync = trip
        endStopText = ""
        
        // Sync to Firestore
        Task {
            do {
                try await api.uploadTrip(tripToSync)
                try? modelContext.save() // Save the isSynced = true state
            } catch {
                print("Failed to sync completed trip: \(error.localizedDescription)")
            }
        }
    }
    
    private func forgotTrip() {
        guard let trip = activeTrip else { return }
        
        // Mark as 15 mins ago or just end now if unknown
        trip.endTime = trip.startTime.addingTimeInterval(15 * 60)
        trip.notes = (trip.notes ?? "") + " (Flagged as forgotten)"
        
        try? modelContext.save()
        
        let tripToSync = trip
        Task {
            try? await api.uploadTrip(tripToSync)
            try? modelContext.save()
        }
    }
    
    private func discardTrip() {
        guard let trip = activeTrip else { return }
        modelContext.delete(trip)
        try? modelContext.save()
    }
    
    // Helper to extract top 4 unique shortcuts
    private struct ShortcutOption {
        let route: String
        let stopName: String
        let direction: String
        let command: String
    }
    
    private func getShortcutOptions() -> [ShortcutOption] {
        // Use the new on-device PredictionEngine to rank history
        let predictions = PredictionEngine.predict(history: completedTrips, stopName: nil)
        
        var options: [ShortcutOption] = []
        var seen = Set<String>()
        
        for prediction in predictions {
            // Find the most recent trip matching this route/direction to get the stop name
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
    
    private func updateCameraPosition() {
        guard !mapMarkers.isEmpty else { return }
        let coordinates = mapMarkers.map { $0.coordinate }
        
        var minLat = 90.0
        var maxLat = -90.0
        var minLon = 180.0
        var maxLon = -180.0
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5 + 0.01,
            longitudeDelta: (maxLon - minLon) * 1.5 + 0.01
        )
        
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - Map Support Types

struct TripMarker: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let count: Int
    let label: String
    let route: String
    var isActive: Bool = false
}

// MARK: - Map Support Views

struct HubView: View {
    let marker: TripMarker
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Pulsing glow for active trips
            if marker.isActive {
                Circle()
                    .stroke(Color.orange.opacity(0.5), lineWidth: 4)
                    .frame(width: 32, height: 32)
                    .scaleEffect(isAnimating ? 1.5 : 1.0)
                    .opacity(isAnimating ? 0 : 1)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
            }
            
            Circle()
                .fill(marker.isActive ? Color.orange : Color.blue)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.3), radius: 3)
            
            if marker.isActive {
                Image(systemName: "tram.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            } else {
                Text("\(marker.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(scaleForCount(marker.count))
        .transition(.scale.combined(with: .opacity))
    }
    
    private func scaleForCount(_ count: Int) -> CGFloat {
        if marker.isActive { return 1.1 }
        // Scale hubs slightly based on frequency (1x to 1.5x)
        return min(1.0 + CGFloat(count - 1) * 0.05, 1.5)
    }
}
