import SwiftUI
import SwiftData
import Combine
import MapKit
import FirebaseAuth

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
    @Query(filter: #Predicate<TripRecord> { $0.endTime == nil && $0.isSynced == false }, sort: \TripRecord.startTime, order: .reverse)
    private var activeTrips: [TripRecord]
    
    @Query(sort: \TripRecord.startTime, order: .reverse)
    private var completedTrips: [TripRecord]
    
    @Query private var hubsLibrary: [Hub]
    @Query private var stopsLibrary: [Stop]
    
    @StateObject private var api = TransitStatsAPI.shared
    @StateObject private var locationManager = LocationManager.shared
    @EnvironmentObject private var appEnv: AppEnvironment
    private var accent: Color { appEnv.accent }
    
    @State private var endStopText = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isShowingAddTripSheet = false
    @State private var isShowingSettingsSheet = false
    @State private var activeRouteText = ""

    // Panel State
    private let snapHeights: [CGFloat] = [140, 300, 600]
    @State private var panelHeight: CGFloat = 300
    @State private var dragOffset: CGFloat = 0
    private var effectivePanelHeight: CGFloat { max(snapHeights[0], panelHeight + dragOffset) }

    // Map State
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    private var mapMarkers: [TripMarker] {
        var hubs: [String: (lat: Double, lon: Double, count: Int, route: String)] = [:]

        for trip in completedTrips {
            guard let name = trip.startStopName ?? trip.startStopCode else { continue }

            // Prefer trip GPS; fall back to stop library coordinates
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
            // Try to find pretty name from hubsLibrary
            let hubName = hubsLibrary.first(where: { $0.id == name })?.name ?? name
            
            return TripMarker(
                id: name,
                coordinate: CLLocationCoordinate2D(latitude: data.lat, longitude: data.lon),
                count: data.count,
                label: hubName,
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
                    Annotation("", coordinate: marker.coordinate) {
                        HubView(marker: marker)
                    }
                }
                UserAnnotation()
            }
            .preferredColorScheme(.dark)
            .mapStyle(.standard)
            .mapControls { }
            .onAppear { updateCameraPosition() }
            .onChange(of: mapMarkers.count) {
                withAnimation(.spring()) { updateCameraPosition() }
            }
            .ignoresSafeArea()

            // Settings button — top right
            VStack {
                HStack {
                    Spacer()
                    Button(action: { isShowingSettingsSheet = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 8)
                Spacer()
            }

            // Compass + Locate buttons — bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        // Compass — resets to north-up
                        MapCompass()
                            .mapControlVisibility(.visible)

                        // Locate me
                        Button(action: {
                            withAnimation(.spring()) {
                                if let coord = locationManager.lastLocation?.coordinate {
                                    cameraPosition = .region(MKCoordinateRegion(
                                        center: coord,
                                        span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                                    ))
                                } else {
                                    cameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
                                }
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.trailing, 16)
                }
                .padding(.bottom, effectivePanelHeight + 16)
            }
        // Bottom panel — ZStack overlay so the tab bar stays visible
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                // Dedicated Drag Zone
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 36, height: 4)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.001)) // Make it tappable
                .gesture(
                    DragGesture()
                        .onChanged { value in dragOffset = -value.translation.height }
                        .onEnded { _ in
                            let nearest = snapHeights.min(by: { abs($0 - (panelHeight + dragOffset)) < abs($1 - (panelHeight + dragOffset)) }) ?? 270
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                panelHeight = nearest
                                dragOffset = 0
                            }
                        }
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if let trip = activeTrip {
                            activeTripCard(trip)
                                .onAppear { updateTimer(for: trip) }
                                .onReceive(timer) { _ in updateTimer(for: trip) }
                        } else {
                            readyStateCard
                        }
                        if !api.lastReplies.isEmpty {
                            repliesPanel
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 110)
                }
            }
            .frame(height: effectivePanelHeight)
            .background(Color.appBackground)
            .background(.ultraThinMaterial)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .ignoresSafeArea(edges: .bottom)
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingSettingsSheet) {
            SettingsView()
                .presentationDetents([.medium, .large])
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
        VStack(spacing: 20) {
            // Status Row
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                    Text("In Transit")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                        .kerning(0.5)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(accent.opacity(0.12))
                .cornerRadius(20)
                
                Spacer()
                
                Text(trip.agency)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
                    .kerning(1)
            }
            
            // Route Header
            if trip.route.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Which route?")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Enter or select below")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("ELAPSED")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.3))
                                .kerning(1)
                            Text(timeElapsed)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(accent)
                        }
                    }
                    
                    HStack(spacing: 10) {
                        TextField("e.g. 506, Line 1, GO Lakeshore", text: $activeRouteText)
                            .font(.system(size: 14, weight: .medium))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .autocorrectionDisabled()
                        
                        Button(action: {
                            let enteredRoute = activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !enteredRoute.isEmpty {
                                withAnimation {
                                    trip.route = enteredRoute
                                    // Query prediction engine to auto-apply direction and agency
                                    let preds = PredictionEngine.predict(history: completedTrips, stopName: trip.startStopName)
                                        .filter { $0.route.lowercased() == enteredRoute.lowercased() }
                                    if let best = preds.first {
                                        trip.direction = best.direction
                                    }
                                    if let match = completedTrips.first(where: { $0.route.lowercased() == enteredRoute.lowercased() }) {
                                        trip.agency = match.agency
                                    }
                                    try? modelContext.save()
                                    activeRouteText = ""
                                }
                            }
                        }) {
                            Text("Apply")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.06) : accent)
                                .foregroundColor(activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.3) : .white)
                                .cornerRadius(12)
                        }
                        .disabled(activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    let routeSuggestions = PredictionEngine.predict(history: completedTrips, stopName: trip.startStopName).filter { !$0.route.isEmpty }
                    if !routeSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(routeSuggestions.prefix(5), id: \.route) { pred in
                                    Button(action: {
                                        withAnimation {
                                            trip.route = pred.route
                                            trip.direction = pred.direction
                                            if let match = completedTrips.first(where: { $0.route == pred.route }) {
                                                trip.agency = match.agency
                                            }
                                            try? modelContext.save()
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(pred.route)
                                                .font(.system(size: 18, weight: .black, design: .rounded))
                                                .foregroundColor(accent)
                                            if !pred.direction.isEmpty {
                                                Text(pred.direction.uppercased())
                                                    .font(.system(size: 9, weight: .black))
                                                    .foregroundColor(.white.opacity(0.4))
                                                    .kerning(0.5)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(accent.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.route)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        if !trip.direction.isEmpty {
                            Text(trip.direction.uppercased())
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.white.opacity(0.4))
                                .kerning(0.8)
                        }
                    }
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ELAPSED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                            .kerning(1)
                        Text(timeElapsed)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(accent)
                    }
                }
            }

            
            // Timeline
            HStack(spacing: 0) {
                // Origin
                VStack(alignment: .leading, spacing: 6) {
                    Text("Origin")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    Text(trip.startStopName ?? trip.startStopCode ?? "Unknown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Connection Graphic
                HStack(spacing: 6) {
                    Circle().fill(accent).frame(width: 5, height: 5)
                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4]))
                        .frame(height: 1)
                        .foregroundColor(.white.opacity(0.15))
                    Image(systemName: "tram.fill")
                        .font(.system(size: 12))
                        .foregroundColor(accent)
                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4]))
                        .frame(height: 1)
                        .foregroundColor(.white.opacity(0.15))
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 5, height: 5)
                }
                .frame(width: 80)
                
                // Destination
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Destination")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    Text(endStopText.isEmpty ? "..." : endStopText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(endStopText.isEmpty ? .white.opacity(0.2) : .white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 8)
            
            Divider().background(Color.white.opacity(0.06))
            
            // End trip input
            VStack(spacing: 12) {
                TextField("Enter exit stop name or code", text: $endStopText)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                let exitSuggestions = PredictionEngine.predictExitStops(history: completedTrips, route: trip.route, startStopName: trip.startStopName)
                if !exitSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(exitSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    endStopText = suggestion
                                    endTrip()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.system(size: 9))
                                            .foregroundColor(.white.opacity(0.6))
                                        Text(suggestion)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                
                HStack(spacing: 12) {
                    Button(action: endTrip) {
                        HStack {
                            Spacer()
                            if api.isSendingCommand {
                                ProgressView().tint(.white)
                            } else {
                                Text("COMPLETE JOURNEY")
                                    .font(.system(size: 12, weight: .black))
                                    .kerning(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(trip.route.isEmpty ? Color.white.opacity(0.08) : accent)
                        .foregroundColor(trip.route.isEmpty ? Color.white.opacity(0.3) : .white)
                        .cornerRadius(12)
                        .shadow(color: trip.route.isEmpty ? .clear : accent.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .disabled(api.isSendingCommand || trip.route.isEmpty)
                    
                    Menu {
                        Button("Forgot to End", role: .none, action: forgotTrip)
                        Button("Discard Trip", role: .destructive, action: discardTrip)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 48, height: 48)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(24)
    }

    private var readyStateCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 6, height: 6)
                    Text("Ready")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .kerning(0.5)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(20)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Ready to go?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Log your next commute or transit journey to keep your stats up to date.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .lineSpacing(2)
            }
            
            Button(action: { isShowingAddTripSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 14))
                    Text("START NEW TRIP")
                        .font(.system(size: 12, weight: .black))
                        .kerning(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [accent, .brandBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: accent.opacity(0.2), radius: 10, x: 0, y: 5)
            }
        }
        .padding(24)
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
            .background(accent.opacity(0.12))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accent.opacity(0.2), lineWidth: 1)
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
                                        .foregroundColor(accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(accent.opacity(0.15))
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

        // Start high-fidelity tracking
        locationManager.startPathTracking()
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

        // Capture path data
        trip.pathData = locationManager.stopPathTracking()

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
    @EnvironmentObject private var appEnv: AppEnvironment
    private var accent: Color { appEnv.accent }
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            if marker.isActive {
                // Active trip: Glowing pulsing ring
                Circle()
                    .stroke(accent, lineWidth: 2)
                    .frame(width: 36, height: 36)
                    .scaleEffect(isAnimating ? 1.4 : 0.8)
                    .opacity(isAnimating ? 0 : 0.6)
                    .onAppear {
                        withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
                
                Circle()
                    .fill(accent)
                    .frame(width: 28, height: 28)
                    .shadow(color: accent.opacity(0.4), radius: 8, x: 0, y: 4)
                
                Image(systemName: "tram.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            } else {
                // Inactive hub: Heatmap dot with translucent border
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    
                    Circle()
                        .fill(accent)
                        .opacity(heatmapIntensity(for: marker.count))
                        .frame(width: 12, height: 12)
                        .shadow(color: accent.opacity(marker.count > 5 ? 0.4 : 0), radius: 4)
                }
            }
        }
        .scaleEffect(marker.isActive ? 1.1 : scaleForCount(marker.count))
        .animation(.spring(), value: marker.isActive)
    }
    
    private func heatmapIntensity(for count: Int) -> Double {
        // Base visibility 0.2, scales up to 1.0 at 15+ trips
        min(0.2 + (Double(count) / 15.0) * 0.8, 1.0)
    }
    
    private func scaleForCount(_ count: Int) -> CGFloat {
        // Very subtle scaling to keep the heatmap clean
        min(0.9 + CGFloat(count) * 0.02, 1.3)
    }
}
