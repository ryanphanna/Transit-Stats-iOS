import SwiftUI
import Combine
import FirebaseAuth

struct ReadyStatePanel: View {
    @ObservedObject var viewModel: HomeViewModel
    let completedTrips: [TripRecord]
    @EnvironmentObject private var appEnv: AppEnvironment
    private var accent: Color { appEnv.accent }

    var body: some View {
        VStack(spacing: 0) {
            // Quick stats strip
            if !completedTrips.isEmpty {
                let tripsThisWeek = completedTrips.filter {
                    Calendar.current.isDate($0.startTime, equalTo: Date(), toGranularity: .weekOfYear)
                }.count
                HStack(spacing: 0) {
                    quickStat(value: "\(completedTrips.count)", label: "TOTAL")
                    Divider().background(Color.white.opacity(0.06)).frame(height: 28)
                    quickStat(value: "\(tripsThisWeek)", label: "THIS WEEK")
                    if let last = completedTrips.first {
                        Divider().background(Color.white.opacity(0.06)).frame(height: 28)
                        quickStat(
                            value: "Just now",
                            label: "LAST TRIP"
                        )
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)

                Divider().background(Color.white.opacity(0.06))
            }

            // Start button + shortcuts
            VStack(spacing: 16) {
                Button(action: { viewModel.isShowingAddTripSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 14))
                        Text("START NEW TRIP")
                            .font(.system(size: 12, weight: .black))
                            .kerning(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [accent, .brandBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: accent.opacity(0.2), radius: 10, x: 0, y: 5)
                }

                // Quick-start shortcuts
                let shortcuts = viewModel.getShortcutOptions(completedTrips: completedTrips)
                if !shortcuts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("QUICK START")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white.opacity(0.3))
                            .kerning(1.5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(shortcuts, id: \.command) { s in
                                    Button(action: { viewModel.startShortcut(s, userId: AuthManager.shared.currentUser?.uid) }) {
                                        HStack(spacing: 8) {
                                            Text(s.route)
                                                .font(.system(size: 15, weight: .black, design: .rounded))
                                                .foregroundColor(accent)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(s.stopName)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                if !s.direction.isEmpty {
                                                    Text(s.direction)
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.white.opacity(0.35))
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.15), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                // Recent trips
                let recent = Array(completedTrips.prefix(3))
                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RECENT")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white.opacity(0.3))
                            .kerning(1.5)

                        VStack(spacing: 6) {
                            ForEach(recent) { trip in
                                HStack(spacing: 10) {
                                    Text(trip.route.isEmpty ? "—" : trip.route)
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(trip.route.isEmpty ? .white.opacity(0.2) : .white)
                                        .frame(width: 32, height: 32)
                                        .background(trip.route.isEmpty ? Color.white.opacity(0.04) : accent.opacity(0.75))
                                        .cornerRadius(8)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(trip.startStopName ?? trip.startStopCode ?? "—")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        if let end = trip.endStopName {
                                            Text("→ \(end)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.4))
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Text("Recently")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.25))
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func quickStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .black))
                .kerning(1)
                .foregroundColor(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
