import SwiftUI
import SwiftData
import PhotosUI
import MapKit

@MainActor
class StatsViewModel: ObservableObject {
    @Published var selectedYear: Int? = nil
    @Published var profileImage: UIImage? = nil
    @Published var pickerItem: PhotosPickerItem? = nil
    
    // Panel State
    let snapHeights: [CGFloat] = [140, 480, 800]
    @Published var panelHeight: CGFloat = 480
    @Published var dragOffset: CGFloat = 0
    
    var effectivePanelHeight: CGFloat {
        max(snapHeights[0], panelHeight + dragOffset)
    }
    
    // Map State
    @Published var cameraPosition: MapCameraPosition = .automatic

    func getAvailableYears(allTrips: [TripRecord]) -> [Int] {
        let calendar = Calendar.current
        return Array(Set(allTrips.map { calendar.component(.year, from: $0.startTime) }))
            .sorted().reversed()
    }

    func getFilteredTrips(allTrips: [TripRecord]) -> [TripRecord] {
        guard let year = selectedYear else { return allTrips }
        let calendar = Calendar.current
        return allTrips.filter { calendar.component(.year, from: $0.startTime) == year }
    }

    func calculateTotalMinutes(completedTrips: [TripRecord]) -> Int {
        completedTrips.reduce(0) { $0 + ($1.durationMinutes ?? 0) }
    }

    func calculateUniqueRoutes(trips: [TripRecord]) -> Int {
        Set(trips.map { $0.route }.filter { !$0.isEmpty }).count
    }

    func calculateUniqueDays(trips: [TripRecord]) -> Int {
        let calendar = Calendar.current
        return Set(trips.map { calendar.startOfDay(for: $0.startTime) }).count
    }

    func calculateUniqueStops(trips: [TripRecord]) -> Int {
        let starts = trips.compactMap { $0.startStopName ?? $0.startStopCode }
        let ends = trips.compactMap { $0.endStopName ?? $0.endStopCode }
        return Set(starts + ends).count
    }

    func calculateTopRoutes(trips: [TripRecord]) -> [(route: String, count: Int)] {
        let groups = Dictionary(grouping: trips.filter { !$0.route.isEmpty }) { $0.route }
        return groups.map { (route: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    func calculateCurrentStreak(allTrips: [TripRecord]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tripDaySet = Set(allTrips.map { calendar.startOfDay(for: $0.startTime) })
        var checkDate = tripDaySet.contains(today) ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        var streak = 0
        while tripDaySet.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }

    func calculateLongestStreak(allTrips: [TripRecord]) -> Int {
        let days = Set(allTrips.filter { $0.endTime != nil }.map { Calendar.current.startOfDay(for: $0.startTime) }).sorted()
        guard !days.isEmpty else { return 0 }
        let calendar = Calendar.current
        var longest = 1, current = 1
        for i in 1..<days.count {
            let diff = calendar.dateComponents([.day], from: days[i-1], to: days[i]).day ?? 0
            if diff == 1 {
                current += 1
                if current > longest { longest = current }
            } else { current = 1 }
        }
        return longest
    }

    func calculateAgencyStats(trips: [TripRecord]) -> [(agency: String, count: Int)] {
        let groups = Dictionary(grouping: trips.filter { !$0.agency.isEmpty }) { $0.agency }
        return groups.map { (agency: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    func calculateWeekdayStats(completedTrips: [TripRecord]) -> [(day: String, count: Int)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let groups = Dictionary(grouping: completedTrips) { formatter.string(from: $0.startTime) }
        return ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"].map { day in
            (day: day, count: groups[day]?.count ?? 0)
        }
    }

    func formatJoinDate(profile: UserProfile?, allTrips: [TripRecord]) -> String {
        let date = profile?.joinedAt ?? allTrips.last?.startTime ?? Date()
        return date.formatted(.dateTime.month().year()).uppercased()
    }

    func formattedTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    func routeColor(for route: String) -> Color {
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
    
    func loadProfileImage() {
        profileImage = ProfileImageManager.shared.load()
    }
    
    func handlePickerChange() {
        guard let item = pickerItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                ProfileImageManager.shared.save(image)
                await MainActor.run {
                    self.profileImage = image
                }
            }
        }
    }
}
