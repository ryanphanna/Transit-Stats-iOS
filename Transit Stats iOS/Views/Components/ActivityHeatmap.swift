import SwiftUI

struct ActivityHeatmap: View {
    let allTrips: [TripRecord]
    @EnvironmentObject private var appEnv: AppEnvironment
    private var accent: Color { appEnv.accent }

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

    var body: some View {
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
