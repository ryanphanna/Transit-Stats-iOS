import SwiftUI
import SwiftData
import Combine

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
    
    // Live timer trigger
    @State private var timeElapsed = ""
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    var activeTrip: TripRecord? {
        activeTrips.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "020617").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
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
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isShowingAddTripSheet = true }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $isShowingAddTripSheet) {
                AddTripView()
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
    }
    
    // MARK: - Views
    
    private func activeTripCard(_ trip: TripRecord) -> some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE TRIP")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .kerning(1.2)
                    
                    Text(trip.route)
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "tram.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.circle")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Boarded At")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(trip.startStopName ?? trip.startStopCode ?? "Unknown stop")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
                
                if !trip.direction.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.gray)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Direction")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(trip.direction)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "stopwatch")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(timeElapsed)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider().background(Color.white.opacity(0.1))
            
            // End trip input
            VStack(spacing: 12) {
                TextField("Exit Stop Code or Name", text: $endStopText)
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(api.isSendingCommand)
                    
                    Menu {
                        Button("Forgot to End", role: .none, action: forgotTrip)
                        Button("Discard Trip", role: .destructive, action: discardTrip)
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var readyStateCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.title)
            }
            
            VStack(spacing: 4) {
                Text("Ready to Ride")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Submit a command below or tap a shortcut to start logging.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private var consoleLoggerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Console Logger")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                TextField("e.g. 506 College Westbound", text: $commandText, onCommit: submitCommand)
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                Button(action: submitCommand) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [Color.blue, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 50, height: 50)
                        
                        if api.isSendingCommand {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
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
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
                Button(action: { api.lastReplies = [] }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(api.lastReplies, id: \.self) { reply in
                    Text(reply)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.12))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Shortcuts")
                .font(.headline)
                .foregroundColor(.white)
            
            // Extract top unique route/stop combinations from completed trips
            let shortcuts = getShortcutOptions()
            
            if shortcuts.isEmpty {
                Text("Your regular routes will appear here once you log a few trips.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(shortcuts, id: \.command) { shortcut in
                            Button(action: { startShortcut(shortcut.command) }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(shortcut.route)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.15))
                                        .cornerRadius(6)
                                    
                                    Text(shortcut.stopName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    if !shortcut.direction.isEmpty {
                                        Text(shortcut.direction)
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .frame(width: 140, alignment: .leading)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
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
