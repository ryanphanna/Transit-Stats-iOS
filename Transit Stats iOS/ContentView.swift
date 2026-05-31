import SwiftUI
import SwiftData
import FirebaseAuth

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Group {
            if authManager.isCheckingAuth {
                ZStack {
                    Color(hex: "020617").ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.blue)
                }
            } else if authManager.isAuthenticated {
                MainTabView()
                    .onAppear {
                        if let uid = authManager.currentUser?.uid {
                            SyncManager.shared.startSyncing(modelContext: modelContext, userId: uid)
                        }
                    }
                    .onDisappear {
                        SyncManager.shared.stopSyncing()
                    }
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct LoginView: View {
    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var isEnteringCode = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    @StateObject private var api = TransitStatsAPI.shared
    
    var body: some View {
        ZStack {
            // Premium background gradient
            LinearGradient(
                colors: [Color(hex: "0F172A"), Color(hex: "1E1B4B"), Color(hex: "020617")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Beautiful dynamic icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                        .blur(radius: 4)
                    
                    Image(systemName: "tram.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Transit Stats")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Your personal transit metrics companion")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 20)
                
                // Form Fields
                VStack(spacing: 16) {
                    if !isEnteringCode {
                        TextField("Phone Number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Code sent to \(phoneNumber)")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                            
                            TextField("6-Digit Code", text: $otpCode)
                                .keyboardType(.numberPad)
                                .autocorrectionDisabled()
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEnteringCode)
                .padding(.horizontal)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                // Primary Action Button
                Button(action: {
                    if isEnteringCode {
                        verifyOtp()
                    } else {
                        requestOtp()
                    }
                }) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isEnteringCode ? "Verify & Sign In" : "Send Verification Code")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(
                        LinearGradient(colors: [Color.blue, Color.indigo], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isLoading || (isEnteringCode ? otpCode.isEmpty : phoneNumber.isEmpty))
                .padding(.horizontal)
                
                if isEnteringCode {
                    // Secondary actions to go back or resend code
                    HStack {
                        Button(action: {
                            isEnteringCode = false
                            otpCode = ""
                            errorMessage = nil
                        }) {
                            Text("Change Phone Number")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Button(action: requestOtp) {
                            Text("Resend Code")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func requestOtp() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await api.requestOtp(phoneNumber: phoneNumber)
                await MainActor.run {
                    isLoading = false
                    isEnteringCode = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func verifyOtp() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let customToken = try await api.verifyOtp(phoneNumber: phoneNumber, code: otpCode)
                
                // Sign in to Firebase Auth using Custom Token
                try await Auth.auth().signIn(withCustomToken: customToken)
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "map.fill")
                }
            
            TripsHistoryView()
                .tabItem {
                    Label("Trips", systemImage: "clock.fill")
                }
            
            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
        }
        .tint(.blue)
    }
}

struct TripsHistoryView: View {
    @Query(sort: \TripRecord.startTime, order: .reverse) private var trips: [TripRecord]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(trips) { trip in
                    TripRow(trip: trip)
                }
            }
            .navigationTitle("Trip History")
            .overlay {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Yet",
                        systemImage: "tram",
                        description: Text("Your completed trips will appear here once logged.")
                    )
                }
            }
        }
    }
}

struct TripRow: View {
    let trip: TripRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trip.route)
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(6)
                    .foregroundColor(.blue)
                
                if !trip.direction.isEmpty {
                    Text(trip.direction)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if let duration = trip.durationMinutes {
                    Text("\(duration) min")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 6) {
                Image(systemName: "circle.circle")
                    .foregroundColor(.green)
                    .font(.caption)
                Text(trip.startStopName ?? trip.startStopCode ?? "Unknown stop")
                    .font(.subheadline)
            }
            
            if let endName = trip.endStopName {
                HStack(spacing: 6) {
                    Image(systemName: "circle.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(endName)
                        .font(.subheadline)
                }
            }
            
            HStack {
                Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if let notes = trip.notes, !notes.isEmpty {
                    Image(systemName: "note.text")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                
                if trip.isSynced {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(authManager.currentUser?.email ?? "User")
                                .fontWeight(.semibold)
                            Text("ID: \(authManager.currentUser?.uid.prefix(8) ?? "")...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("App Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.41.1")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Platform")
                        Spacer()
                        Text("iOS Native")
                            .foregroundColor(.gray)
                    }
                }
                
                Section {
                    Button(role: .destructive, action: { authManager.signOut() }) {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// Color Hex conversion helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
