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
    
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var api = TransitStatsAPI.shared
    @StateObject private var locationManager = LocationManager.shared
    @EnvironmentObject private var appEnv: AppEnvironment
    private var accent: Color { appEnv.accent }
    
    private var mapMarkers: [TripMarker] {
        viewModel.generateMapMarkers(
            completedTrips: completedTrips,
            stopsLibrary: stopsLibrary,
            hubsLibrary: hubsLibrary,
            activeTrip: activeTrip
        )
    }
    
    // Live timer trigger
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var activeTrip: TripRecord? {
        activeTrips.first
    }
    
    var body: some View {
        ZStack {
            // Full Screen Interactive Map Background
            Map(position: $viewModel.cameraPosition) {
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
            .onAppear { 
                viewModel.modelContext = modelContext
                viewModel.updateCameraPosition(mapMarkers: mapMarkers) 
            }
            .ignoresSafeArea()

            // Settings button — top right
            VStack {
                HStack {
                    Spacer()
                    Button(action: { viewModel.isShowingSettingsSheet = true }) {
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
                .padding(.top, 16)
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
                            locationManager.startUpdating()
                            if let coord = locationManager.lastLocation?.coordinate {
                                withAnimation(.spring()) {
                                    viewModel.cameraPosition = .region(MKCoordinateRegion(
                                        center: coord,
                                        span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                                    ))
                                }
                            } else {
                                viewModel.pendingLocationZoom = true
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
                .padding(.bottom, viewModel.effectivePanelHeight + 16)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.effectivePanelHeight)
            }
        // Bottom panel — ZStack overlay so tab bar stays visible
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                // Drag handle — large hit target so the whole top of the panel is draggable
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 36, height: 4),
                        alignment: .center
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in viewModel.dragOffset = -value.translation.height }
                            .onEnded { _ in
                                let nearest = viewModel.snapHeights.min(by: { abs($0 - (viewModel.panelHeight + viewModel.dragOffset)) < abs($1 - (viewModel.panelHeight + viewModel.dragOffset)) }) ?? 270
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    viewModel.panelHeight = nearest
                                    viewModel.dragOffset = 0
                                }
                            }
                    )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if let trip = activeTrip {
                            activeTripCard(trip)
                                .onAppear { viewModel.updateTimer(for: trip) }
                                .onReceive(timer) { _ in viewModel.updateTimer(for: trip) }
                        } else {
                            readyStateCard
                        }
                        if !api.lastReplies.isEmpty {
                            repliesPanel
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
            }
            .frame(height: viewModel.effectivePanelHeight)
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
        .onChange(of: locationManager.lastLocation) { _, location in
            viewModel.handleLocationChange(location)
        }
        .sheet(isPresented: $viewModel.isShowingAddTripSheet) {
            AddTripView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $viewModel.isShowingSettingsSheet) {
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
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.55))
                        .frame(width: 6, height: 6)
                    Text("In Transit")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.55))
                        .kerning(0.5)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 0.2, green: 0.85, blue: 0.55).opacity(0.12))
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
                            Text(viewModel.timeElapsed)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(accent)
                        }
                    }
                    
                    HStack(spacing: 10) {
                        TextField("e.g. 506, Line 1, GO Lakeshore", text: $viewModel.activeRouteText)
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
                            let enteredRoute = viewModel.activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines)
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
                                    viewModel.activeRouteText = ""
                                }
                            }
                        }) {
                            Text("Apply")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(viewModel.activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.06) : accent)
                                .foregroundColor(viewModel.activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.3) : .white)
                                .cornerRadius(12)
                        }
                        .disabled(viewModel.activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                        Text(viewModel.timeElapsed)
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
                    Text(viewModel.endStopText.isEmpty ? "..." : viewModel.endStopText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(viewModel.endStopText.isEmpty ? .white.opacity(0.2) : .white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 8)
            
            Divider().background(Color.white.opacity(0.06))
            
            // End trip input
            VStack(spacing: 12) {
                TextField("Enter exit stop name or code", text: $viewModel.endStopText)
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
                                    viewModel.endStopText = suggestion
                                    viewModel.endTrip(activeTrip: trip)
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
                    Button(action: { viewModel.endTrip(activeTrip: trip) }) {
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
                        Button("Forgot to End", role: .none, action: { viewModel.forgotTrip(activeTrip: trip) })
                        Button("Discard Trip", role: .destructive, action: { viewModel.discardTrip(activeTrip: trip) })
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
        VStack(spacing: 0) {
            // Quick stats strip
            if !completedTrips.isEmpty {
                let tripsThisWeek = completedTrips.filter {
                    Calendar.current.isDate($0.startTime, equalTo: Date(), toGranularity: .weekOfYear)
                }.count
                HStack(spacing: 0) {
                    quickStat(value: "\(completedTrips.count)", label: "TOTAL")
                    Divider().background(Color.white.opacity(0.06)).frame(height: 28)
                    quickStat(value: "\(tripsThisWeek)", label: "THIS WEEK")
                    if let last = completedTrips.first {
                        Divider().background(Color.white.opacity(0.06)).frame(height: 28)
                        quickStat(
                            value: last.startTime.formatted(.relative(presentation: .named, unitsStyle: .narrow)),
                            label: "LAST TRIP"
                        )
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)

                Divider().background(Color.white.opacity(0.06))
            }

            // Start button + shortcuts
            VStack(spacing: 16) {
                Button(action: { viewModel.isShowingAddTripSheet = true }) {
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

                // Quick-start shortcuts
                let shortcuts = viewModel.getShortcutOptions(completedTrips: completedTrips)
                if !shortcuts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("QUICK START")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white.opacity(0.3))
                            .kerning(1.5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(shortcuts, id: \.command) { s in
                                    Button(action: { viewModel.startShortcut(s, userId: AuthManager.shared.currentUser?.uid) }) {
                                        HStack(spacing: 8) {
                                            Text(s.route)
                                                .font(.system(size: 15, weight: .black, design: .rounded))
                                                .foregroundColor(accent)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(s.stopName)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                if !s.direction.isEmpty {
                                                    Text(s.direction)
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.white.opacity(0.35))
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.15), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                // Recent trips
                let recent = Array(completedTrips.prefix(3))
                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RECENT")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white.opacity(0.3))
                            .kerning(1.5)

                        VStack(spacing: 6) {
                            ForEach(recent) { trip in
                                HStack(spacing: 10) {
                                    Text(trip.route.isEmpty ? "—" : trip.route)
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(trip.route.isEmpty ? .white.opacity(0.2) : .white)
                                        .frame(width: 32, height: 32)
                                        .background(trip.route.isEmpty ? Color.white.opacity(0.04) : accent.opacity(0.75))
                                        .cornerRadius(8)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(trip.startStopName ?? trip.startStopCode ?? "—")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        if let end = trip.endStopName {
                                            Text("→ \(end)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.4))
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Text(trip.startTime.formatted(.relative(presentation: .named, unitsStyle: .narrow)))
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.25))
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func quickStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .black))
                .kerning(1)
                .foregroundColor(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
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
