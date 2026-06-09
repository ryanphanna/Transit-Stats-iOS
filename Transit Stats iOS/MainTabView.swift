import SwiftUI
import SwiftData
import FirebaseAuth
import PhotosUI

struct MainTabView: View {
    @StateObject private var appEnv = AppEnvironment()
    @Query(sort: \TripRecord.startTime, order: .reverse) private var allTrips: [TripRecord]
    @State private var isShowingGoSheet = false

    private var topAgency: String? {
        let groups = Dictionary(grouping: allTrips.filter { !$0.agency.isEmpty }) { $0.agency }
        return groups.max(by: { $0.value.count < $1.value.count })?.key
    }

    private var accent: Color { appEnv.accent }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                TripsHistoryView()
                    .tabItem { Label("Trips", systemImage: "clock.fill") }
                HomeView()
                    .tabItem { Label("Explore", systemImage: "map.fill") }
                StatsView()
                    .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            }
            .tint(accent)
            .environmentObject(appEnv)
            .onAppear { appEnv.homeAgency = topAgency }
            .onChange(of: topAgency) { _, new in appEnv.homeAgency = new }

            // Floating Go button — always accessible above tab bar
            Button(action: { isShowingGoSheet = true }) {
                HStack(spacing: 7) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("GO")
                        .font(.system(size: 13, weight: .black))
                        .kerning(1.5)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(accent)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: accent.opacity(0.45), radius: 14, x: 0, y: 6)
            }
            .padding(.bottom, 78)
        }
        .sheet(isPresented: $isShowingGoSheet) {
            AddTripView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }
}
