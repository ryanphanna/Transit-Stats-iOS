import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Group {
            if authManager.isCheckingAuth {
                ZStack {
                    Color.appBackground.ignoresSafeArea()
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
