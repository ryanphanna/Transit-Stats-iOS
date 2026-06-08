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
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                // Subtle top gradient glow
                VStack {
                    LinearGradient(colors: [accent.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 300)
                    Spacer()
                }
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Hero: Route & Agency
                        VStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(accent.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 28)
                                            .stroke(accent.opacity(0.3), lineWidth: 1)
                                    )

                                if trip.route.isEmpty {
                                    Image(systemName: "tram.fill")
                                        .font(.system(size: 38, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.35))
                                } else {
                                    Text(trip.route)
                                        .font(.system(size: 44, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                        .padding(10)
                                }
                            }
                            .shadow(color: accent.opacity(0.2), radius: 20, x: 0, y: 10)

                            VStack(spacing: 4) {
                                if !trip.agency.isEmpty {
                                    Text(trip.agency.uppercased())
                                        .font(.system(size: 13, weight: .black))
                                        .kerning(2)
                                        .foregroundColor(accent)
                                }
                                if !trip.direction.isEmpty {
                                    Text(trip.direction)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                        .padding(.top, 20)

                        // Path Map
                        if !trip.path.isEmpty || (trip.startLatitude != nil && trip.endLatitude != nil) {
                            pathMap
                                .frame(height: 180)
                                .cornerRadius(24)
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.06), lineWidth: 1))
                                .padding(.horizontal, 20)
                        }

                        // Timeline Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("JOURNEY")
                                .font(.system(size: 10, weight: .black))
                                .kerning(1.5)
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.leading, 4)

                            VStack(spacing: 0) {
                                // Boarded
                                timelineRow(
                                    icon: "arrow.up.right.circle.fill",
                                    iconColor: accent,
                                    label: "Boarded",
                                    stop: trip.startStopName ?? trip.startStopCode ?? (trip.source == "sms" ? "Via SMS" : "Unknown"),
                                    time: trip.startTime
                                )

                                // Connecting line
                                HStack(spacing: 0) {
                                    VStack(spacing: 4) {
                                        ForEach(0..<3) { _ in
                                            Circle()
                                                .fill(accent.opacity(0.3))
                                                .frame(width: 3, height: 3)
                                        }
                                    }
                                    .frame(width: 32)
                                    
                                    if let d = trip.durationMinutes {
                                        Text("\(d) minute trip")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.25))
                                            .padding(.leading, 12)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)

                                // Exited
                                timelineRow(
                                    icon: "arrow.down.right.circle.fill",
                                    iconColor: .white.opacity(0.2),
                                    label: "Exited",
                                    stop: trip.endStopName ?? trip.endStopCode ?? "Ongoing / Unknown",
                                    time: trip.endTime
                                )
                            }
                            .padding(20)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }

                        // Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            statBox(value: durationText, label: "DURATION", icon: "clock.fill")
                            statBox(value: trip.startTime.formatted(.dateTime.day().month()), label: "DATE", icon: "calendar")
                            statBox(value: trip.startTime.formatted(.dateTime.hour().minute()), label: "TIME", icon: "timer")
                        }

                        // Details List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DETAILS")
                                .font(.system(size: 10, weight: .black))
                                .kerning(1.5)
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.leading, 4)

                            VStack(spacing: 0) {
                                metaRow(icon: "antenna.radiowaves.left.and.right", label: "Source", value: trip.source == "sms" ? "SMS Sync" : "App Native")
                                Divider().background(Color.white.opacity(0.06))
                                metaRow(
                                    icon: trip.isSynced ? "checkmark.circle.fill" : "arrow.clockwise.circle.fill",
                                    label: "Cloud Sync",
                                    value: trip.isSynced ? "Verified" : "Pending"
                                )
                                
                                if let vehicle = trip.vehicle, !vehicle.isEmpty {
                                    Divider().background(Color.white.opacity(0.06))
                                    metaRow(icon: "bus.fill", label: "Vehicle", value: vehicle)
                                }
                                
                                if let notes = trip.notes, !notes.isEmpty {
                                    Divider().background(Color.white.opacity(0.06))
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "note.text")
                                                .font(.system(size: 14))
                                                .foregroundColor(accent)
                                            Text("Notes")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.6))
                                            Spacer()
                                        }
                                        Text(notes)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .lineSpacing(4)
                                    }
                                    .padding(16)
                                }
                            }
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

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
