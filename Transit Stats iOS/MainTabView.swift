import SwiftUI
import SwiftData
import FirebaseAuth
import PhotosUI

struct MainTabView: View {
    @StateObject private var appEnv = AppEnvironment()
    @Query(sort: \TripRecord.startTime, order: .reverse) private var allTrips: [TripRecord]

    private var topAgency: String? {
        let groups = Dictionary(grouping: allTrips.filter { !$0.agency.isEmpty }) { $0.agency }
        return groups.max(by: { $0.value.count < $1.value.count })?.key
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "map.fill") }
            TripsHistoryView()
                .tabItem { Label("Trips", systemImage: "clock.fill") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
        }
        .tint(appEnv.accent)
        .environmentObject(appEnv)
        .onAppear { appEnv.homeAgency = topAgency }
        .onChange(of: topAgency) { _, new in appEnv.homeAgency = new }
    }
}
