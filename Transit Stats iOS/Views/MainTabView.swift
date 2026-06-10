import SwiftUI
import SwiftData
import FirebaseAuth
import PhotosUI

struct MainTabView: View {
    @StateObject private var appEnv = AppEnvironment()
    @Query(sort: \TripRecord.startTime, order: .reverse) private var allTrips: [TripRecord]
    @State private var selectedTab = 0
    @State private var isShowingGoSheet = false

    private var topAgency: String? {
        let groups = Dictionary(grouping: allTrips.filter { !$0.agency.isEmpty }) { $0.agency }
        return groups.max(by: { $0.value.count < $1.value.count })?.key
    }

    private var accent: Color { appEnv.accent }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Screen Content
            TabView(selection: $selectedTab) {
                TripsHistoryView()
                    .tag(0)
                    .toolbar(.hidden, for: .tabBar)
                
                HomeView()
                    .tag(1)
                    .toolbar(.hidden, for: .tabBar)
                
                StatsView()
                    .tag(2)
                    .toolbar(.hidden, for: .tabBar)
                
                SettingsView()
                    .tag(3)
                    .toolbar(.hidden, for: .tabBar)
            }
            .environmentObject(appEnv)
            .onAppear { appEnv.homeAgency = topAgency }
            .onChange(of: topAgency) { _, new in appEnv.homeAgency = new }

            // Custom Floating "Liquid Glass" Tab Bar
            FloatingTabBar(selectedTab: $selectedTab, isShowingGoSheet: $isShowingGoSheet)
                .environmentObject(appEnv)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $isShowingGoSheet) {
            AddTripView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }
}
