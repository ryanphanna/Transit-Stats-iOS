import SwiftUI
import SwiftData
import FirebaseAuth
import PhotosUI
import MapKit

struct TripDetailView: View {
    @EnvironmentObject private var appEnv: AppEnvironment
    let trip: TripRecord
    @Environment(\.dismiss) private var dismiss
    private var accent: Color { appEnv.accent }

    private var durationText: String {
        guard let d = trip.durationMinutes else { return "—" }
        return d >= 60 ? "\(d / 60)h \(d % 60)m" : "\(d)m"
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Subtle top gradient glow
            VStack {
                LinearGradient(colors: [accent.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 300)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Manual header — replaces NavigationStack to avoid nav bar disappearing
                HStack {
                    Text("Trip Details")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // Header: Route + Agency
                        HStack(spacing: 14) {
                            if !trip.route.isEmpty {
                                Text(trip.route)
                                    .font(.system(size: 30, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(accent.opacity(0.15))
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.25), lineWidth: 1))
                            } else {
                                Image(systemName: "tram.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(accent.opacity(0.5))
                                    .padding(12)
                                    .background(accent.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                if !trip.agency.isEmpty {
                                    Text(trip.agency.uppercased())
                                        .font(.system(size: 14, weight: .black))
                                        .kerning(1.5)
                                        .foregroundColor(accent)
                                }
                                if !trip.direction.isEmpty {
                                    Text(trip.direction)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 8)

                        // All info in one card
                        VStack(spacing: 0) {

                            // From / To compact timeline
                            HStack(alignment: .top, spacing: 12) {
                                VStack(spacing: 0) {
                                    Circle().fill(accent).frame(width: 8, height: 8).padding(.top, 5)
                                    Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1).frame(maxHeight: .infinity)
                                    Circle().fill(Color.white.opacity(0.3)).frame(width: 8, height: 8).padding(.bottom, 5)
                                }
                                .frame(width: 8)

                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("FROM").font(.system(size: 9, weight: .black)).kerning(1).foregroundColor(.white.opacity(0.3))
                                            Text(trip.startStopName ?? trip.startStopCode ?? (trip.source == "sms" ? "Via SMS" : "Unknown"))
                                                .font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(1)
                                        }
                                        Spacer()
                                        Text(trip.startTime.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding(.bottom, 10)

                                    if let d = trip.durationMinutes {
                                        Text("\(d) min")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.2))
                                            .padding(.bottom, 10)
                                    }

                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("TO").font(.system(size: 9, weight: .black)).kerning(1).foregroundColor(.white.opacity(0.3))
                                            Text(trip.endStopName ?? trip.endStopCode ?? (trip.endTime == nil ? "Ongoing" : "Unknown"))
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(trip.endTime == nil ? .white.opacity(0.4) : .white)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if let end = trip.endTime {
                                            Text(end.formatted(date: .omitted, time: .shortened))
                                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                }
                            }
                            .padding(16)

                            Divider().background(Color.white.opacity(0.06))

                            // Stats strip
                            HStack(spacing: 0) {
                                compactStat(label: "DATE",     value: trip.startTime.formatted(.dateTime.day().month()))
                                Divider().background(Color.white.opacity(0.06)).frame(height: 32)
                                compactStat(label: "DURATION", value: durationText)
                            }
                            .padding(.vertical, 12)

                            if let vehicle = trip.vehicle, !vehicle.isEmpty {
                                Divider().background(Color.white.opacity(0.06))
                                HStack {
                                    Image(systemName: "bus.fill").font(.system(size: 12)).foregroundColor(accent.opacity(0.7))
                                    Text("Vehicle").font(.system(size: 13)).foregroundColor(.white.opacity(0.5))
                                    Spacer()
                                    Text(vehicle).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                            }

                            if let notes = trip.notes, !notes.isEmpty {
                                Divider().background(Color.white.opacity(0.06))
                                HStack(alignment: .top) {
                                    Image(systemName: "note.text").font(.system(size: 12)).foregroundColor(accent.opacity(0.7))
                                    Text(notes).font(.system(size: 13)).foregroundColor(.white.opacity(0.8)).lineSpacing(3)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                            }

                            // Source + sync small print
                            Divider().background(Color.white.opacity(0.06))
                            HStack(spacing: 6) {
                                Text("Logged via \(trip.source == "sms" ? "SMS" : "App")")
                                Text("·").foregroundColor(.white.opacity(0.2))
                                Text(trip.isSynced ? "Synced" : "Sync pending")
                                    .foregroundColor(trip.isSynced ? .white.opacity(0.25) : accent.opacity(0.6))
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.25))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 1))

                        // Path Map (if available)
                        if !trip.path.isEmpty || (trip.startLatitude != nil && trip.endLatitude != nil) {
                            pathMap
                                .frame(height: 160)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Helpers

    private func compactStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .black)).kerning(1)
                .foregroundColor(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private func timelineRow(icon: String, iconColor: Color, label: String, stop: String, time: Date?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .kerning(1)
                    .foregroundColor(.white.opacity(0.3))
                Text(stop)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let t = time {
                Text(t.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private func statBox(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(accent)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 8, weight: .black))
                    .kerning(1)
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func metaRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(accent.opacity(0.8))
                .frame(width: 24)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(16)
    }

    private var pathMap: some View {
        Map {
            if let startLat = trip.startLatitude, let startLon = trip.startLongitude {
                Marker("Boarded", coordinate: CLLocationCoordinate2D(latitude: startLat, longitude: startLon))
                    .tint(accent)
            }
            if let endLat = trip.endLatitude, let endLon = trip.endLongitude {
                Marker("Exited", coordinate: CLLocationCoordinate2D(latitude: endLat, longitude: endLon))
                    .tint(.gray)
            }
            if !trip.path.isEmpty {
                MapPolyline(coordinates: trip.path.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) })
                    .stroke(accent, lineWidth: 3)
            }
        }
        .mapStyle(.standard(emphasis: .muted))
    }
}
