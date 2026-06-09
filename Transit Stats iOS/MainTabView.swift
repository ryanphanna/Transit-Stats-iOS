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
        Group {
            if #available(iOS 26.0, *) {
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
                .tabViewBottomAccessory {
                    Button(action: { isShowingGoSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "tram.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("GO")
                                .font(.system(size: 13, weight: .black))
                                .kerning(1)
                        }
                        .tint(accent)
                    }
                }
            } else {
                // Fallback for iOS < 26
                ZStack(alignment: .bottomTrailing) {
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

                    Button(action: { isShowingGoSheet = true }) {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(accent)
                            .frame(width: 52, height: 52)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(accent.opacity(0.35), lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 22)
                }
            }
        }
        .sheet(isPresented: $isShowingGoSheet) {
            AddTripView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }
}
