import SwiftUI
import SwiftData
import Combine
import MapKit
import FirebaseAuth

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TripRecord> { $0.endTime == nil && $0.isSynced == false }, sort: \TripRecord.startTime, order: .reverse)
    private var activeTrips: [TripRecord]
    
    @Query(sort: \TripRecord.startTime, order: .reverse)
    private var completedTrips: [TripRecord]
    
    @Query private var hubsLibrary: [Hub]
    @Query private var stopsLibrary: [Stop]
    
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var tripService = TripService.shared
    @StateObject private var locationManager = LocationManager.shared
    @EnvironmentObject private var appEnv: AppEnvironment
    
    private var mapMarkers: [TripMarker] {
        viewModel.generateMapMarkers(
            completedTrips: completedTrips,
            stopsLibrary: stopsLibrary,
            hubsLibrary: hubsLibrary,
            activeTrip: activeTrips.first
        )
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

            // Map Overlay Controls
            mapOverlayControls

            // Sliding Bottom Panel
            slidingBottomPanel
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
            get: { tripService.lastError != nil },
            set: { if !$0 { tripService.lastError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tripService.lastError ?? "")
        }
    }
    
    // MARK: - Components

    private var mapOverlayControls: some View {
        VStack {
            // Settings button — top right
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
            
            // Compass + Locate buttons — bottom right
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    MapCompass().mapControlVisibility(.visible)
                    
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
    }

    private var slidingBottomPanel: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                // Drag handle
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
                        if let trip = activeTrips.first {
                            ActiveTripCard(trip: trip, viewModel: viewModel, tripService: tripService, completedTrips: completedTrips)
                        } else {
                            ReadyStatePanel(viewModel: viewModel, completedTrips: completedTrips)
                        }
                        
                        if !tripService.lastReplies.isEmpty {
                            NetworkUpdatePanel(tripService: tripService)
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
}
