import SwiftUI
import Charts

struct WeekdayChartSection: View {
    let stats: [(day: String, count: Int)]
    @EnvironmentObject private var appEnv: AppEnvironment
    private var accent: Color { appEnv.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BY DAY OF WEEK")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white.opacity(0.4))
                .kerning(1.5)
            Chart {
                ForEach(stats, id: \.day) { stat in
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
}

struct AgencyStatsSection: View {
    let stats: [(agency: String, count: Int)]
    @EnvironmentObject private var appEnv: AppEnvironment
    private var accent: Color { appEnv.accent }

    var body: some View {
        if stats.count > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text("TOP AGENCIES")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(1.5)
                    .padding(.horizontal, 20)
                ForEach(stats.prefix(5), id: \.agency) { stat in
                    agencyRow(stat)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func agencyRow(_ stat: (agency: String, count: Int)) -> some View {
        let total = stats.reduce(0) { $0 + $1.count }
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
}

struct TopRoutesSection: View {
    let routes: [(route: String, count: Int)]
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        if !routes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("TOP ROUTES")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(1.5)
                    .padding(.horizontal, 20)
                ForEach(routes.prefix(6), id: \.route) { stat in
                    routeCard(stat)
                }
                .padding(.horizontal, 20)
            }
        }
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
}
