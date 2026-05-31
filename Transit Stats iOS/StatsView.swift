import SwiftUI
import Charts
import SwiftData

struct StatsView: View {
    @Query(sort: \TripRecord.startTime, order: .reverse) private var trips: [TripRecord]
    
    // Group trips by Route and sort by count
    private var routeStats: [(route: String, count: Int)] {
        let groups = Dictionary(grouping: trips) { $0.route }
        return groups.map { (route: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
    
    // Group trips by day of week
    private var weekdayStats: [(day: String, count: Int)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // e.g. Mon, Tue
        
        let groups = Dictionary(grouping: trips) { formatter.string(from: $0.startTime) }
        let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        
        return daysOfWeek.map { day in
            (day: day, count: groups[day]?.count ?? 0)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "020617").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Summary metrics
                        HStack(spacing: 16) {
                            summaryCard(title: "Total Trips", value: "\(trips.count)", icon: "tram.fill", color: .blue)
                            summaryCard(title: "Active Time", value: "\(totalActiveMinutes())m", icon: "clock.fill", color: .green)
                        }
                        
                        // Favorite Routes Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top 5 Favorite Routes")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if routeStats.isEmpty {
                                Text("No route data available. Completed trips will appear here.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            } else {
                                Chart {
                                    ForEach(routeStats, id: \.route) { stat in
                                        BarMark(
                                            x: .value("Trips", stat.count),
                                            y: .value("Route", stat.route)
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.blue, Color.indigo],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(4)
                                    }
                                }
                                .frame(height: 200)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                        
                        // Weekly Distribution Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Trips by Weekday")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if trips.isEmpty {
                                Text("No data available.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            } else {
                                Chart {
                                    ForEach(weekdayStats, id: \.day) { stat in
                                        BarMark(
                                            x: .value("Day", stat.day),
                                            y: .value("Trips", stat.count)
                                        )
                                        .foregroundStyle(Color.green.gradient)
                                        .cornerRadius(4)
                                    }
                                }
                                .frame(height: 200)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Analytics")
        }
    }
    
    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func totalActiveMinutes() -> Int {
        trips.reduce(0) { sum, trip in
            sum + (trip.durationMinutes ?? 0)
        }
    }
}
