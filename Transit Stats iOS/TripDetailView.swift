import SwiftUI
import SwiftData
import FirebaseAuth
import PhotosUI

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

                ScrollView {
                    VStack(spacing: 20) {

                        // Route badge + agency
                        VStack(spacing: 10) {
                            Text(trip.route.isEmpty ? "?" : trip.route)
                                .font(.system(size: 40, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .frame(width: 90, height: 90)
                                .background(trip.route.isEmpty ? Color.white.opacity(0.08) : accent.opacity(0.85))
                                .cornerRadius(22)

                            if !trip.agency.isEmpty {
                                Text(trip.agency)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            if !trip.direction.isEmpty {
                                Text(trip.direction)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        }
                        .padding(.top, 8)

                        // Origin → Destination timeline
                        VStack(spacing: 0) {
                            detailCard {
                                VStack(spacing: 16) {
                                    timelineStop(
                                        label: "Boarded",
                                        stop: trip.startStopName ?? trip.startStopCode ?? (trip.source == "sms" ? "Via SMS" : "Unknown"),
                                        time: trip.startTime,
                                        isOrigin: true
                                    )

                                    HStack {
                                        Rectangle()
                                            .fill(accent.opacity(0.3))
                                            .frame(width: 2, height: 24)
                                            .padding(.leading, 11)
                                        Spacer()
                                        if let d = trip.durationMinutes {
                                            Text("\(d) min")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                    }

                                    timelineStop(
                                        label: "Alighted",
                                        stop: trip.endStopName ?? trip.endStopCode ?? "—",
                                        time: trip.endTime,
                                        isOrigin: false
                                    )
                                }
                            }
                        }

                        // Stats row
                        HStack(spacing: 12) {
                            statPill(value: durationText, label: "Duration")
                            statPill(value: trip.startTime.formatted(date: .abbreviated, time: .omitted), label: "Date")
                            statPill(value: trip.startTime.formatted(date: .omitted, time: .shortened), label: "Time")
                        }

                        // Meta
                        detailCard {
                            VStack(spacing: 0) {
                                metaRow(icon: "iphone", label: "Source", value: trip.source == "sms" ? "SMS" : "App")
                                Divider().background(Color.white.opacity(0.06))
                                metaRow(
                                    icon: trip.isSynced ? "checkmark.icloud.fill" : "arrow.triangle.2.circlepath",
                                    label: "Sync",
                                    value: trip.isSynced ? "Synced" : "Pending"
                                )
                                if let vehicle = trip.vehicle, !vehicle.isEmpty {
                                    Divider().background(Color.white.opacity(0.06))
                                    metaRow(icon: "bus.fill", label: "Vehicle", value: vehicle)
                                }
                                if let notes = trip.notes, !notes.isEmpty {
                                    Divider().background(Color.white.opacity(0.06))
                                    metaRow(icon: "note.text", label: "Notes", value: notes)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(accent)
                }
            }
        }
        .presentationBackground(Color(hex: "020617"))
    }

    private func timelineStop(label: String, stop: String, time: Date?, isOrigin: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isOrigin ? accent : Color.white.opacity(0.2))
                .frame(width: 10, height: 10)
                .padding(.leading, 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
                    .textCase(.uppercase)
                Text(stop)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            Spacer()
            if let t = time {
                Text(t.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func metaRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(accent.opacity(0.7))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.45))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
    }

    private func detailCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
