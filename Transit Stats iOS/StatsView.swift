import SwiftUI
import Charts
import SwiftData

struct StatsView: View {
    @Query(sort: \TripRecord.startTime, order: .reverse) private var allTrips: [TripRecord]
    @Query private var profiles: [UserProfile]
    @Query private var accuracies: [PredictionAccuracy]
    @State private var selectedYear: Int? = nil
    @AppStorage("appAccent") private var accentKey: String = "blue"

    private var profile: UserProfile? { profiles.first }

    private var topAgency: String? {
        let groups = Dictionary(grouping: allTrips.filter { !$0.agency.isEmpty }) { $0.agency }
        return groups.max(by: { $0.value.count < $1.value.count })?.key
    }
    private var accent: Color { AppTheme(rawValue: accentKey)?.resolved(topAgency: topAgency) ?? .blue }

    private var availableYears: [Int] {
        let calendar = Calendar.current
        return Array(Set(allTrips.map { calendar.component(.year, from: $0.startTime) }))
            .sorted().reversed()
    }

    private var trips: [TripRecord] {
        guard let year = selectedYear else { return allTrips }
        let calendar = Calendar.current
        return allTrips.filter { calendar.component(.year, from: $0.startTime) == year }
    }

    private var completedTrips: [TripRecord] { trips.filter { $0.endTime != nil } }

    private var totalMinutes: Int {
        completedTrips.reduce(0) { $0 + ($1.durationMinutes ?? 0) }
    }

    private var uniqueRoutes: Int {
        Set(trips.map { $0.route }.filter { !$0.isEmpty }).count
    }

    private var uniqueStops: Int {
        let starts = trips.compactMap { $0.startStopName ?? $0.startStopCode }
        let ends = trips.compactMap { $0.endStopName ?? $0.endStopCode }
        return Set(starts + ends).count
    }

    private var topRoutes: [(route: String, count: Int)] {
        let groups = Dictionary(grouping: trips.filter { !$0.route.isEmpty }) { $0.route }
        return groups.map { (route: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var topRoute: String {
        topRoutes.first?.route ?? "N/A"
    }

    private var tripDaySet: Set<Date> {
        let calendar = Calendar.current
        let allCompleted = allTrips.filter { $0.endTime != nil }
        return Set(allCompleted.map { calendar.startOfDay(for: $0.startTime) })
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var checkDate = tripDaySet.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today)!
        var streak = 0
        while tripDaySet.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }

    private var longestStreak: Int {
        let days = tripDaySet.sorted()
        guard !days.isEmpty else { return 0 }
        let calendar = Calendar.current
        var longest = 1, current = 1
        for i in 1..<days.count {
            let diff = calendar.dateComponents([.day], from: days[i-1], to: days[i]).day ?? 0
            if diff == 1 {
                current += 1
                if current > longest { longest = current }
            } else {
                current = 1
            }
        }
        return longest
    }

    private var rank: String {
        let count = allTrips.count
        if count < 10  { return "New Rider" }
        if count < 50  { return "Regular" }
        if count < 200 { return "Pro Commuter" }
        if count < 500 { return "Transit Expert" }
        return "System Master"
    }

    private var agencyStats: [(agency: String, count: Int)] {
        let groups = Dictionary(grouping: allTrips.filter { !$0.agency.isEmpty }) { $0.agency }
        return groups.map { (agency: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var joinDate: String {
        let date = profile?.joinedAt ?? allTrips.last?.startTime ?? Date()
        return date.formatted(.dateTime.month().year()).uppercased()
    }

    private var weekdayStats: [(day: String, count: Int)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let groups = Dictionary(grouping: completedTrips) { formatter.string(from: $0.startTime) }
        return ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"].map { day in
            (day: day, count: groups[day]?.count ?? 0)
        }
    }

    private func formattedTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private func routeColor(for route: String) -> Color {
        switch route.uppercased() {
        case "1":  return Color(hex: "F5A623")
        case "2":  return Color(hex: "2E8B57")
        case "3":  return Color(hex: "4169E1")
        case "4":  return Color(hex: "8B008B")
        default:
            if let num = Int(route.prefix(while: { $0.isNumber })), num >= 500 && num < 600 {
                return Color(hex: "A0001A")
            }
            let palette = ["1B5E9B","7B3F8C","1A6B5A","7A3B1E","2C4F8C","8B3A3A"]
            return Color(hex: palette[abs(route.hashValue) % palette.count])
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "020617").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Profile / Transit Card
                        transitCard
                            .padding(.horizontal, 20)
                            .padding(.top, 4)

                        // Year filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                yearPill(label: "ALL TIME", year: nil)
                                ForEach(availableYears, id: \.self) { year in
                                    yearPill(label: "\(year)", year: year)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Passport card
                        passportCard
                            .padding(.horizontal, 20)

                        // Streaks
                        streakCard
                            .padding(.horizontal, 20)

                        // Agencies
                        if agencyStats.count > 1 {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("AGENCIES")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.white.opacity(0.4))
                                    .kerning(1.5)
                                    .padding(.horizontal, 20)

                                ForEach(agencyStats, id: \.agency) { stat in
                                    agencyRow(stat)
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // Top Routes
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

                        // Weekday chart
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

                        Spacer(minLength: 40)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Stats")
        }
    }

    // MARK: - Subviews

    private func yearPill(label: String, year: Int?) -> some View {
        let selected = selectedYear == year
        return Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedYear = year } }) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(selected ? .white : .white.opacity(0.45))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? Color.blue : Color.white.opacity(0.07))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private var passportCard: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TRANSIT PASS")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white.opacity(0.5))
                        .kerning(2)
                    Text(selectedYear.map { "\($0)" } ?? "ALL TIME")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                }
                Spacer()
                Image(systemName: "tram.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 20)

            // Stats grid
            HStack(spacing: 0) {
                passportStat(value: "\(trips.count)", label: "TRIPS")
                Divider().background(Color.white.opacity(0.08)).frame(height: 40)
                passportStat(value: formattedTime(totalMinutes), label: "TIME")
            }
            .padding(.vertical, 16)

            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 20)

            HStack(spacing: 0) {
                passportStat(value: "\(uniqueRoutes)", label: "ROUTES")
                Divider().background(Color.white.opacity(0.08)).frame(height: 40)
                passportStat(value: "\(uniqueStops)", label: "STOPS")
            }
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "0d1b3e"), Color(hex: "0a0f1e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func passportStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.white.opacity(0.35))
                .kerning(1.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private func routeCard(_ stat: (route: String, count: Int)) -> some View {
        let color = routeColor(for: stat.route)
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

    // MARK: - Transit Card (profile hero)

    private var transitCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: [Color(hex: "0d1b3e"), Color(hex: "0a0f1e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 10)

            RoundedRectangle(cornerRadius: 24)
                .stroke(LinearGradient(
                    colors: [.white.opacity(0.3), .clear, .white.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "tram.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(accent)
                    Text("TRANSIT STATS")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white)
                        .kerning(1.5)
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Text(profile?.nickname?.prefix(1).uppercased() ?? "T")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(accent)
                    }
                }
                .padding(24)

                Spacer()

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MEMBER SINCE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text(joinDate)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("RANK")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text(rank)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(accent)
                    }
                }
                .padding(24)
            }
        }
        .frame(height: 200)
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
            // Current streak
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

            // Best streak
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
        .background(
            LinearGradient(
                colors: [Color(hex: "0d1b3e"), Color(hex: "0a0f1e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
