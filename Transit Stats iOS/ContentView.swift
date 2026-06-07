import SwiftUI
import SwiftData
import FirebaseAuth

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
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
                            
                            // Sync profile and library metadata
                            SyncManager.shared.syncProfile(modelContext: modelContext, userId: uid)
                            SyncManager.shared.syncStops(modelContext: modelContext)
                            
                            // Also sync any pending trips from previous offline sessions
                            if networkMonitor.isConnected {
                                SyncManager.shared.syncPendingTrips(modelContext: modelContext)
                            }
                        }
                    }
                    .onDisappear {
                        SyncManager.shared.stopSyncing()
                    }
                    .onChange(of: networkMonitor.isConnected) { oldValue, newValue in
                        if newValue && !oldValue {
                            SyncManager.shared.syncPendingTrips(modelContext: modelContext)
                        }
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
    @State private var showingLogin = false
    @State private var resendCooldown: Int = 0

    @StateObject private var api = TransitStatsAPI.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F172A"), Color(hex: "0a0f1e")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if showingLogin {
                loginForm
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                landingScreen
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showingLogin)
    }

    // MARK: - Landing Screen

    private var landingScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                        .blur(radius: 20)
                    Image(systemName: "tram.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Transit Stats")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Know your commute better\nthan the TTC does.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            VStack(spacing: 10) {
                featureRow(icon: "tram.circle.fill",
                           color: .blue,
                           title: "Log every trip",
                           detail: "Start and end trips in seconds, anywhere")
                featureRow(icon: "chart.bar.fill",
                           color: .indigo,
                           title: "See your patterns",
                           detail: "Routes, time, stops — all tracked over time")
                featureRow(icon: "message.fill",
                           color: Color(hex: "5E5CE6"),
                           title: "Works with your texts",
                           detail: "Log via SMS too, syncs to the app instantly")
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        showingLogin = true
                    }
                }) {
                    HStack {
                        Spacer()
                        Text("Get Started")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [Color.blue, Color.indigo],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .cornerRadius(14)
                    .foregroundColor(.white)
                    .shadow(color: Color.blue.opacity(0.35), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 28)

                Text("Sign in with your phone number")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.bottom, 52)
        }
    }

    // MARK: - Login Form

    private var loginForm: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        showingLogin = false
                        isEnteringCode = false
                        phoneNumber = ""
                        otpCode = ""
                        errorMessage = nil
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15))
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))

                Text(isEnteringCode ? "Enter your code" : "Sign in")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(isEnteringCode
                     ? "We sent a 6-digit code to \(phoneNumber)"
                     : "Enter your phone number to continue")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .animation(.easeInOut(duration: 0.2), value: isEnteringCode)

            Spacer()

            VStack(spacing: 14) {
                if !isEnteringCode {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    TextField("6-Digit Code", text: $otpCode)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: { isEnteringCode ? verifyOtp() : requestOtp() }) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isEnteringCode ? "Verify & Sign In" : "Send Code")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [Color.blue, Color.indigo],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .cornerRadius(14)
                    .foregroundColor(.white)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isLoading || (isEnteringCode ? otpCode.isEmpty : phoneNumber.isEmpty))

                if isEnteringCode {
                    HStack {
                        Button(action: {
                            isEnteringCode = false
                            otpCode = ""
                            errorMessage = nil
                        }) {
                            Text("Change Number")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Button(action: requestOtp) {
                            Text(resendCooldown > 0 ? "Resend in \(resendCooldown)s" : "Resend Code")
                                .font(.subheadline)
                                .foregroundColor(resendCooldown > 0 ? .white.opacity(0.2) : .white.opacity(0.35))
                        }
                        .disabled(resendCooldown > 0)
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEnteringCode)
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
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
                    startResendCooldown()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startResendCooldown() {
        resendCooldown = 60
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { resendCooldown -= 1 }
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
            ZStack {
                Color(hex: "020617").ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(trips) { trip in
                            TripRow(trip: trip)
                        }
                    }
                    .padding()
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

    private var originLabel: String {
        trip.startStopName ?? trip.startStopCode ?? (trip.source == "sms" ? "Via SMS" : "—")
    }

    private var hasOrigin: Bool {
        trip.startStopName != nil || trip.startStopCode != nil
    }

    var body: some View {
        HStack(spacing: 14) {
            // Route badge
            VStack {
                Text(trip.route.isEmpty ? "?" : trip.route)
                    .font(.system(size: trip.route.count > 4 ? 11 : 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(width: 48, height: 48)
                    .background(trip.route.isEmpty ? Color.white.opacity(0.08) : Color.blue.opacity(0.85))
                    .cornerRadius(12)
            }

            // Main info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(originLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(hasOrigin ? .white : .white.opacity(0.35))
                        .lineLimit(1)

                    if let end = trip.endStopName {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.25))
                        Text(end)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))

                    if !trip.direction.isEmpty {
                        Text("·")
                            .foregroundColor(.white.opacity(0.2))
                        Text(trip.direction)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }

            Spacer()

            // Duration + sync
            VStack(alignment: .trailing, spacing: 6) {
                if let duration = trip.durationMinutes {
                    Text("\(duration)m")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.blue)
                }
                Image(systemName: trip.isSynced ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(trip.isSynced ? .white.opacity(0.2) : .white.opacity(0.4))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @Query private var profiles: [UserProfile]
    @Query(sort: \TripRecord.startTime, order: .reverse) private var allTrips: [TripRecord]
    @AppStorage("appAccent") private var accentKey: String = "blue"

    private var profile: UserProfile? { profiles.first }

    private var topAgency: String? {
        let groups = Dictionary(grouping: allTrips.filter { !$0.agency.isEmpty }) { $0.agency }
        return groups.max(by: { $0.value.count < $1.value.count })?.key
    }

    private var accent: Color {
        AppTheme(rawValue: accentKey)?.resolved(topAgency: topAgency) ?? .blue
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading) {
                            Text(profile?.nickname ?? authManager.currentUser?.email ?? "User")
                                .fontWeight(.semibold)
                            Text("Account ID: \(authManager.currentUser?.uid.prefix(4) ?? "")••••\(authManager.currentUser?.uid.suffix(4) ?? "")")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Plan") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile?.isPremium == true ? "Transit Stats Premium" : "Transit Stats Free")
                                .fontWeight(.semibold)
                            Text(profile?.isPremium == true ? "All features unlocked" : "Basic trip logging")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if profile?.isPremium == true {
                            Text("ACTIVE")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(accent.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("Theme") {
                    HStack(spacing: 12) {
                        ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                            Button(action: { accentKey = theme.rawValue }) {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(theme == .auto
                                                  ? AppTheme.agencyColor(for: topAgency)
                                                  : theme.swatchColor)
                                            .frame(width: 32, height: 32)
                                        if accentKey == theme.rawValue {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .black))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    Text(theme.label)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(accentKey == theme.rawValue ? accent : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if profile?.isAdmin == true {
                    Section("Developer") {
                        Toggle(isOn: $locationManager.isHighFidelityEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Breadcrumb Tracking")
                                    .fontWeight(.medium)
                                Text("Records GPS path during trips. Higher battery usage.")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .tint(.blue)
                    }
                }
                
                Section("App Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.42.0")
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
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
