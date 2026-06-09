import SwiftUI
import Charts
import SwiftData
import PhotosUI
import MapKit

struct StatsView: View {
    @Query(sort: \TripRecord.startTime, order: .reverse) private var allTrips: [TripRecord]
    @Query private var profiles: [UserProfile]
    @EnvironmentObject private var appEnv: AppEnvironment
    @StateObject private var viewModel = StatsViewModel()
    
    private var profile: UserProfile? { profiles.first }
    private var accent: Color { appEnv.accent }

    private var availableYears: [Int] {
        viewModel.getAvailableYears(allTrips: allTrips)
    }

    private var trips: [TripRecord] {
        viewModel.getFilteredTrips(allTrips: allTrips)
    }

    private var completedTrips: [TripRecord] { trips.filter { $0.endTime != nil } }

    var body: some View {
        ZStack {
            Map(position: $viewModel.cameraPosition) {
                ForEach(allTrips.filter { $0.pathData != nil }) { trip in
                    MapPolyline(coordinates: trip.path.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) })
                        .stroke(accent.opacity(0.4), lineWidth: 2)
                }
                UserAnnotation()
            }
            .preferredColorScheme(.dark)
            .mapStyle(.standard)
            .mapControls { }
            .ignoresSafeArea()

            Color.black.opacity(min(0.4, Double(viewModel.effectivePanelHeight - 140) / 1000.0))
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()
                passportPanel
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear { viewModel.loadProfileImage() }
        .onChange(of: viewModel.pickerItem) { _, _ in
            viewModel.handlePickerChange()
        }
    }

    private var passportPanel: some View {
        VStack(spacing: 0) {
            panelHeader
            panelScrollContent
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

    private var panelHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top) {
                Text("Passport")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                PhotosPicker(selection: $viewModel.pickerItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        if let img = viewModel.profileImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(accent.opacity(0.12))
                                .frame(width: 48, height: 48)
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundColor(accent.opacity(0.6))
                        }
                    }
                    .overlay(Circle().stroke(accent.opacity(0.3), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 5)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    yearPill(label: "All-Time", year: nil)
                    ForEach(availableYears, id: \.self) { year in
                        yearPill(label: "\(year)", year: year)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 4)
        }
        .background(Color.appBackground)
        .background(.ultraThinMaterial)
        .gesture(
            DragGesture()
                .onChanged { value in viewModel.dragOffset = -value.translation.height }
                .onEnded { _ in
                    let currentHeight = viewModel.panelHeight + viewModel.dragOffset
                    let nearest = viewModel.snapHeights.min(by: { abs($0 - currentHeight) < abs($1 - currentHeight) }) ?? 480
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        viewModel.panelHeight = nearest
                        viewModel.dragOffset = 0
                    }
                }
        )
    }

    private var panelScrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                PassportCard(
                    year: viewModel.selectedYear,
                    trips: trips,
                    totalMinutes: viewModel.calculateTotalMinutes(completedTrips: completedTrips),
                    uniqueRoutes: viewModel.calculateUniqueRoutes(trips: trips),
                    uniqueStops: viewModel.calculateUniqueStops(trips: trips),
                    uniqueDays: viewModel.calculateUniqueDays(trips: trips),
                    agencyCount: viewModel.calculateAgencyStats(trips: trips).count,
                    nickname: profile?.nickname ?? "TRANSIT RIDER",
                    joinDate: viewModel.formatJoinDate(profile: profile, allTrips: allTrips),
                    formattedTime: viewModel.formattedTime(viewModel.calculateTotalMinutes(completedTrips: completedTrips))
                )
                .padding(.horizontal, 20)
                
                StreakCard(
                    currentStreak: viewModel.calculateCurrentStreak(allTrips: allTrips),
                    longestStreak: viewModel.calculateLongestStreak(allTrips: allTrips)
                )
                .padding(.horizontal, 20)
                
                ActivityHeatmap(allTrips: allTrips)
                
                AgencyStatsSection(stats: viewModel.calculateAgencyStats(trips: trips))
                
                TopRoutesSection(routes: viewModel.calculateTopRoutes(trips: trips), viewModel: viewModel)
                
                WeekdayChartSection(stats: viewModel.calculateWeekdayStats(completedTrips: completedTrips))
                
                Spacer(minLength: 120)
            }
            .padding(.top, 10)
        }
    }

    private func yearPill(label: String, year: Int?) -> some View {
        let selected = viewModel.selectedYear == year
        return Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { viewModel.selectedYear = year } }) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(selected ? .white : .white.opacity(0.35))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? Color.white.opacity(0.12) : Color.clear)
                .clipShape(Capsule())
        }
    }
}
