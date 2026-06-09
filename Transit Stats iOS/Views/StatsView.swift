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

    private var totalMinutes: Int {
        viewModel.calculateTotalMinutes(completedTrips: completedTrips)
    }

    private var uniqueRoutes: Int {
        viewModel.calculateUniqueRoutes(trips: trips)
    }

    private var uniqueDays: Int {
        viewModel.calculateUniqueDays(trips: trips)
    }

    private var uniqueStops: Int {
        viewModel.calculateUniqueStops(trips: trips)
    }

    private var topRoutes: [(route: String, count: Int)] {
        viewModel.calculateTopRoutes(trips: trips)
    }

    private var currentStreak: Int {
        viewModel.calculateCurrentStreak(allTrips: allTrips)
    }

    private var longestStreak: Int {
        viewModel.calculateLongestStreak(allTrips: allTrips)
    }

    private var agencyStats: [(agency: String, count: Int)] {
        viewModel.calculateAgencyStats(trips: trips)
    }

    private var joinDate: String {
        viewModel.formatJoinDate(profile: profile, allTrips: allTrips)
    }

    private var weekdayStats: [(day: String, count: Int)] {
        viewModel.calculateWeekdayStats(completedTrips: completedTrips)
    }

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
                passportCard.padding(.horizontal, 20)
                streakCard.padding(.horizontal, 20)
                heatmapCard
                agenciesSection
                routesSection
                weekdayChartSection
                Spacer(minLength: 120)
            }
            .padding(.top, 10)
        }
    }

    @ViewBuilder private var agenciesSection: some View {
        if agencyStats.count > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text("TOP AGENCIES")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(1.5)
                    .padding(.horizontal, 20)
                ForEach(agencyStats.prefix(5), id: \.agency) { stat in
                    agencyRow(stat)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder private var routesSection: some View {
        if !topRoutes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("TOP ROUTES")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(1.5)
                    .padding(.horizontal, 20)
                ForEach(topRoutes.prefix(6), id: \.route) { stat in
                    routeCard(stat)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var weekdayChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BY DAY OF WEEK")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white.opacity(0.4))
                .kerning(1.5)
            Chart {
                ForEach(weekdayStats, id: \.day) { stat in
                    BarMark(
                        x: .value("Day", stat.day),
                        y: .value("Trips", stat.count)
                    )
                    .foregroundStyle(accent.opacity(0.8).gradient)
                    .cornerRadius(5)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.white.opacity(0.4))
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel()
                        .foregroundStyle(Color.white.opacity(0.3))
                        .font(.system(size: 10))
                }
            }
            .frame(height: 160)
        }
        .padding(20)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - Subviews

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

    private var passportCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Hero Title
            VStack(alignment: .leading, spacing: 4) {
                Text((viewModel.selectedYear.map { "\($0) " } ?? "ALL-TIME ").uppercased() + "TRANSIT PASSPORT")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(accent)
                    .kerning(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 8))
                    Text("PERSONAL TRANSIT RECORD")
                        .font(.system(size: 8, weight: .black))
                        .kerning(1.5)
                }
                .foregroundColor(.white.opacity(0.4))
            }
            
            // Primary Stats
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TRIPS")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(1)
                    Text("\(trips.count)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(agencyStats.count) Agencies")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TIME")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(1)
                    Text(viewModel.formattedTime(totalMinutes))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("In transit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Secondary Stats Grid
            HStack(spacing: 0) {
                miniPassportStat(label: "ROUTES", value: "\(uniqueRoutes)")
                miniPassportStat(label: "STOPS", value: "\(uniqueStops)")
                miniPassportStat(label: "DAYS", value: "\(uniqueDays)")
            }
            
            // Identity row (merged from separate card)
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile?.nickname ?? "TRANSIT RIDER")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("SINCE \(joinDate)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
                Spacer()
            }
        }
        .padding(24)
        .background(
            ZStack {
                Color(hex: "020617")
                LinearGradient(
                    colors: [accent.opacity(0.15), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
    }

    private func miniPassportStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.white.opacity(0.3))
                .kerning(1)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func routeCard(_ stat: (route: String, count: Int)) -> some View {
        let color = viewModel.routeColor(for: stat.route)
        return HStack(spacing: 0) {
            Text(stat.route)
                .font(.system(size: stat.route.count > 4 ? 20 : 26, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.leading, 20)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(stat.count)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(color.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.25))
                .cornerRadius(20)
                .padding(.trailing, 16)
        }
        .frame(height: 62)
        .background(color)
        .cornerRadius(14)
    }

    // MARK: - Agency Row

    private func agencyRow(_ stat: (agency: String, count: Int)) -> some View {
        let total = agencyStats.reduce(0) { $0 + $1.count }
        let fraction = total > 0 ? Double(stat.count) / Double(total) : 0

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(stat.agency)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(stat.count) trips")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accent.opacity(0.8))
                            .frame(width: geo.size.width * fraction, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.system(size: 18))
                    Text("STREAK")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(1.5)
                }
                Text("\(currentStreak)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(currentStreak > 0 ? .white : .white.opacity(0.3))
                Text(currentStreak == 1 ? "day" : "days")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider()
                .background(Color.white.opacity(0.08))
                .frame(height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text("BEST")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(1.5)
                Text("\(longestStreak)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Text(longestStreak == 1 ? "day" : "days")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Color.white.opacity(0.04))
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Activity Heatmap

    private var heatmapCounts: [Date: Int] {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        for trip in allTrips {
            let day = cal.startOfDay(for: trip.startTime)
            counts[day, default: 0] += 1
        }
        return counts
    }

    private var heatmapWeeks: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let thisSunday = cal.date(byAdding: .day, value: -(weekday - 1), to: today)!
        return (0...52).reversed().compactMap { cal.date(byAdding: .weekOfYear, value: -$0, to: thisSunday) }
    }

    private func heatmapColor(for date: Date) -> Color {
        let today = Calendar.current.startOfDay(for: Date())
        guard date <= today else { return .clear }
        let count = heatmapCounts[date] ?? 0
        guard count > 0 else { return Color.white.opacity(0.07) }
        let intensity = 0.15 + min(Double(count), 10.0) / 10.0 * 0.85
        return accent.opacity(intensity)
    }

    private var heatmapCard: some View {
        let cal = Calendar.current
        let weeks = heatmapWeeks
        let monthFmt: DateFormatter = {
            let f = DateFormatter(); f.dateFormat = "MMM"; return f
        }()

        return VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVITY")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white.opacity(0.4))
                .kerning(1.5)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(alignment: .top, spacing: 3) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 16)
                            VStack(spacing: 3) {
                                ForEach(["S","M","T","W","T","F","S"], id: \.self) { label in
                                    Text(label)
                                        .font(.system(size: 7, weight: .medium))
                                        .foregroundColor(.white.opacity(0.25))
                                        .frame(width: 11, height: 11)
                                }
                            }
                        }
                        .padding(.trailing, 2)

                        ForEach(Array(weeks.enumerated()), id: \.offset) { idx, weekStart in
                            VStack(spacing: 0) {
                                let showMonth = idx == 0 || cal.component(.month, from: weekStart) != cal.component(.month, from: weeks[idx - 1])
                                if showMonth {
                                    Text(monthFmt.string(from: weekStart))
                                        .font(.system(size: 7, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.35))
                                        .frame(height: 16, alignment: .leading)
                                        .fixedSize()
                                } else {
                                    Color.clear.frame(height: 16)
                                }
                                VStack(spacing: 3) {
                                    ForEach(0..<7, id: \.self) { dayOffset in
                                        let date = cal.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(heatmapColor(for: date))
                                            .frame(width: 11, height: 11)
                                    }
                                }
                            }
                            .frame(width: 11)
                            .id(idx)
                        }
                    }
                    .padding(.horizontal, 20)
                    .onAppear { proxy.scrollTo(weeks.count - 1, anchor: .trailing) }
                }
            }
            
            HStack(spacing: 4) {
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.25))
                ForEach([0, 2, 4, 6, 8, 10], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level == 0 ? Color.white.opacity(0.07) : accent.opacity(0.15 + Double(level) / 10.0 * 0.85))
                        .frame(width: 11, height: 11)
                }
                Text("More")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.horizontal, 20)
        }
    }
}
