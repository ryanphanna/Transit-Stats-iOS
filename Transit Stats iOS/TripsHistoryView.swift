import SwiftUI
import SwiftData
import FirebaseAuth
import PhotosUI

struct TripsHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appEnv: AppEnvironment
    @Query(sort: \TripRecord.startTime, order: .reverse) private var trips: [TripRecord]
    @State private var selectedTrip: TripRecord? = nil
    @State private var searchText = ""
    @State private var sourceFilter = "all"
    @State private var agencyFilter: String? = nil
    @State private var dateFilter = "all"

    private var accent: Color { appEnv.accent }

    private var availableAgencies: [String] {
        Array(Set(trips.map { $0.agency }.filter { !$0.isEmpty })).sorted()
    }

    private var filtered: [TripRecord] {
        let calendar = Calendar.current
        let now = Date()
        return trips.filter { trip in
            let matchesSearch = searchText.isEmpty
                || trip.route.localizedCaseInsensitiveContains(searchText)
                || (trip.startStopName ?? "").localizedCaseInsensitiveContains(searchText)
                || (trip.endStopName ?? "").localizedCaseInsensitiveContains(searchText)
            let matchesSource = sourceFilter == "all"
                || (sourceFilter == "sms" && trip.source == "sms")
                || (sourceFilter == "app" && trip.source != "sms")
            let matchesAgency = agencyFilter == nil || trip.agency == agencyFilter
            let matchesDate: Bool
            switch dateFilter {
            case "week":  matchesDate = calendar.isDate(trip.startTime, equalTo: now, toGranularity: .weekOfYear)
            case "month": matchesDate = calendar.isDate(trip.startTime, equalTo: now, toGranularity: .month)
            case "year":  matchesDate = calendar.isDate(trip.startTime, equalTo: now, toGranularity: .year)
            default:      matchesDate = true
            }
            return matchesSearch && matchesSource && matchesAgency && matchesDate
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        // Search
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.system(size: 14))
                            TextField("Route, stop, agency…", text: $searchText)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))

                        // Date filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterChip("All time", active: dateFilter == "all")  { dateFilter = "all" }
                                filterChip("This week", active: dateFilter == "week") { dateFilter = "week" }
                                filterChip("This month", active: dateFilter == "month") { dateFilter = "month" }
                                filterChip("This year", active: dateFilter == "year")  { dateFilter = "year" }
                            }
                        }

                        // Source + agency filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterChip("All sources", active: sourceFilter == "all") { sourceFilter = "all" }
                                filterChip("App", active: sourceFilter == "app") { sourceFilter = "app" }
                                filterChip("SMS", active: sourceFilter == "sms") { sourceFilter = "sms" }
                                if availableAgencies.count > 1 {
                                    Divider().frame(height: 16).background(Color.white.opacity(0.15))
                                    ForEach(availableAgencies, id: \.self) { agency in
                                        filterChip(agency, active: agencyFilter == agency) {
                                            agencyFilter = agencyFilter == agency ? nil : agency
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }

                        HStack {
                            Spacer()
                            Text("\(filtered.count) trip\(filtered.count == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.25))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { trip in
                                Button(action: { selectedTrip = trip }) {
                                    TripRow(trip: trip)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive, action: { deleteTrip(trip) }) {
                                        Label("Delete Trip", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteTrip(trip)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Trips")
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        trips.isEmpty ? "No Trips Yet" : "No Results",
                        systemImage: "tram",
                        description: Text(trips.isEmpty
                            ? "Your completed trips will appear here once logged."
                            : "Try adjusting your search or filters.")
                    )
                }
            }
        }
        .sheet(item: $selectedTrip) { trip in
            TripDetailView(trip: trip)
        }
    }

    private func deleteTrip(_ trip: TripRecord) {
        withAnimation {
            modelContext.delete(trip)
            try? modelContext.save()
        }
    }

    private func filterChip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(active ? .white : .white.opacity(0.4))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? accent : Color.white.opacity(0.07))
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

