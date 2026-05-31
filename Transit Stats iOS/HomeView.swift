import SwiftUI
import SwiftData
import Combine
import MapKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TripRecord> { $0.endTime == nil }, sort: \TripRecord.startTime, order: .reverse)
    private var activeTrips: [TripRecord]
    
    @Query(sort: \TripRecord.startTime, order: .reverse)
    private var completedTrips: [TripRecord]
    
    @StateObject private var api = TransitStatsAPI.shared
    
    @State private var commandText = ""
    @State private var endStopText = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isShowingAddTripSheet = false
    @State private var isShowingSettingsSheet = false
    
    // Live timer trigger
    @State private var timeElapsed = ""
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    var activeTrip: TripRecord? {
        activeTrips.first
    }
    
    var body: some View {
        ZStack {
            // Full Screen Interactive Map Background
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )))
            .ignoresSafeArea()
            
            VStack {
                // Top floating UI containing custom liquid glass controls
                HStack {
                    Spacer()
                    
                    // Glassmorphic / Liquid Glass Control Bar
                    HStack(spacing: 16) {
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
                            
                            // Console Logger
                            consoleLoggerSection
                            
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
        .sheet(isPresented: $isShowingAddTripSheet) {
            AddTripView()
        }
        .sheet(isPresented: $isShowingSettingsSheet) {
            SettingsView()
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
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE TRIP")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .kerning(1.2)
                    
                    Text(trip.route)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "tram.fill")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                }
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.circle")
                        .foregroundColor(.green)
                        .font(.footnote)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Boarded At")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(trip.startStopName ?? trip.startStopCode ?? "Unknown stop")
                            .font(.footnote)
                            .foregroundColor(.white)
                    }
                }
                
                if !trip.direction.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.gray)
                            .font(.footnote)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Direction")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Text(trip.direction)
                                .font(.footnote)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "stopwatch")
                        .foregroundColor(.orange)
                        .font(.footnote)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Duration")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(timeElapsed)
                            .font(.footnote)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider().background(Color.white.opacity(0.08))
            
            // End trip input
            VStack(spacing: 10) {
                TextField("Exit Stop Code or Name", text: $endStopText)
                    .font(.footnote)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.06))
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
                                Text("End Trip")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
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
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.25))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var readyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "tram.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 56, height: 56)
                .background(Color.blue.opacity(0.15))
                .clipShape(Circle())
            
            VStack(spacing: 4) {
                Text("Where are you heading?")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Start a new journey or tap a recent shortcut below.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            Button(action: { isShowingAddTripSheet = true }) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.caption)
                    Text("Start New Trip")
                        .fontWeight(.bold)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(LinearGradient(colors: [Color.blue, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.25))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var consoleLoggerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Text Log")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
            
            HStack {
                TextField("e.g. 506 College Westbound", text: $commandText, onCommit: submitCommand)
                    .font(.footnote)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                Button(action: submitCommand) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color.blue, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 38, height: 38)
                        
                        if api.isSendingCommand {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .font(.footnote)
                        }
                    }
                }
                .disabled(api.isSendingCommand || commandText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
    
    private var repliesPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("System Update")
                    .font(.system(size: 10))
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
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
            .background(Color.blue.opacity(0.15))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.25), lineWidth: 1)
            )
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Shortcuts")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
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
                            Button(action: { startShortcut(shortcut.command) }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(shortcut.route)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                    
                                    Text(shortcut.stopName)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    if !shortcut.direction.isEmpty {
                                        Text(shortcut.direction)
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(10)
                                .frame(width: 120, alignment: .leading)
                                .background(Color.black.opacity(0.2))
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
            timeElapsed = "Just started"
        } else {
            timeElapsed = "\(mins) min elapsed"
        }
    }
    
    private func submitCommand() {
        let text = commandText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        Task {
            await api.sendCommand(text)
            commandText = ""
        }
    }
    
    private func startShortcut(_ command: String) {
        Task {
            await api.sendCommand(command)
        }
    }
    
    private func endTrip() {
        let stop = endStopText.trimmingCharacters(in: .whitespaces)
        let command = stop.isEmpty ? "END" : "END \(stop)"
        
        Task {
            await api.sendCommand(command)
            endStopText = ""
        }
    }
    
    private func forgotTrip() {
        Task {
            await api.sendCommand("FORGOT")
        }
    }
    
    private func discardTrip() {
        Task {
            await api.sendCommand("DISCARD")
        }
    }
    
    // Helper to extract top 4 unique shortcuts
    private struct ShortcutOption {
        let route: String
        let stopName: String
        let direction: String
        let command: String
    }
    
    private func getShortcutOptions() -> [ShortcutOption] {
        var options: [ShortcutOption] = []
        var seen = Set<String>()
        
        for trip in completedTrips {
            guard let stopName = trip.startStopName ?? trip.startStopCode else { continue }
            let key = "\(trip.route)|\(stopName)|\(trip.direction)"
            
            if !seen.contains(key) {
                seen.insert(key)
                let command = "\(trip.route) \(stopName) \(trip.direction)".trimmingCharacters(in: .whitespaces)
                options.append(ShortcutOption(
                    route: trip.route,
                    stopName: stopName,
                    direction: trip.direction,
                    command: command
                ))
            }
            
            if options.count >= 4 { break }
        }
        
        return options
    }
}
