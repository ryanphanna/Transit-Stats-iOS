import SwiftUI
import SwiftData
import FirebaseAuth
import PhotosUI

struct TripRow: View {
    @EnvironmentObject private var appEnv: AppEnvironment
    let trip: TripRecord
    private var accent: Color { appEnv.accent }

    private var originLabel: String {
        trip.startStopName ?? trip.startStopCode ?? (trip.source == "sms" ? "Via SMS" : "—")
    }

    private var hasOrigin: Bool {
        trip.startStopName != nil || trip.startStopCode != nil
    }

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if trip.route.isEmpty {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                } else {
                    Text(trip.route)
                        .font(.system(size: trip.route.count > 4 ? 11 : 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
            .frame(width: 48, height: 48)
            .background(trip.route.isEmpty ? Color.white.opacity(0.05) : accent.opacity(0.85))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 3) {
                Text(originLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(hasOrigin ? .white : .white.opacity(0.35))
                    .lineLimit(1)

                if let end = trip.endStopName {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.2))
                        Text(end)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))

                    if !trip.direction.isEmpty {
                        Text("·").foregroundColor(.white.opacity(0.2))
                        Text(trip.direction)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }

            Spacer()

            if let duration = trip.durationMinutes {
                Text("\(duration)m")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(accent.opacity(0.7))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
