import SwiftUI
import SwiftData
import FirebaseAuth
import PhotosUI
import MapKit

struct TripsHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appEnv: AppEnvironment
    @Query(sort: \TripRecord.startTime, order: .reverse) private var trips: [TripRecord]
    @State private var selectedTrip: TripRecord? = nil
    @State private var searchText = ""
    @State private var sourceFilter = "all"
    @State private var agencyFilter: String? = nil
    @State private var dateFilter = "all"
    
    // Panel State
    private let snapHeights: [CGFloat] = [140, 450, 750]
    @State private var panelHeight: CGFloat = 450
    @State private var dragOffset: CGFloat = 0
    private var effectivePanelHeight: CGFloat { max(snapHeights[0], panelHeight + dragOffset) }
    
    // Map State
    @State private var cameraPosition: MapCameraPosition = .automatic

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
        ZStack {
            // Map Background
            Map(position: $cameraPosition) {
                UserAnnotation()
            }
            .preferredColorScheme(.dark)
            .mapStyle(.standard)
            .mapControls { }
            .ignoresSafeArea()
            
            // Background dimming
            Color.black.opacity(min(0.4, (effectivePanelHeight - 140) / 1000))
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Panel Header / Search Bar
                    VStack(spacing: 12) {
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 36, height: 4)
                            .padding(.top, 10)
                        
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.system(size: 14))
                            TextField("Search history…", text: $searchText)
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
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }
                    .background(Color.appBackground)
                    .background(.ultraThinMaterial)
                    .gesture(
                        DragGesture()
                            .onChanged { value in dragOffset = -value.translation.height }
                            .onEnded { _ in
                                let currentHeight = panelHeight + dragOffset
                                let nearest = snapHeights.min(by: { abs($0 - currentHeight) < abs($1 - currentHeight) }) ?? 450
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    panelHeight = nearest
                                    dragOffset = 0
                                }
                            }
                    )

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Date filter
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    filterChip("All time", active: dateFilter == "all")  { dateFilter = "all" }
                                    filterChip("This week", active: dateFilter == "week") { dateFilter = "week" }
                                    filterChip("This month", active: dateFilter == "month") { dateFilter = "month" }
                                    filterChip("This year", active: dateFilter == "year")  { dateFilter = "year" }
                                }
                                .padding(.horizontal, 16)
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
                                }
                                .padding(.horizontal, 16)
                            }

                            if !filtered.isEmpty {
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
                                .padding(.bottom, 110)
                            } else {
                                // Empty state
                                VStack(spacing: 20) {
                                    Image(systemName: "tram")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.2))
                                    Text(trips.isEmpty ? "No Trips Yet" : "No Results")
                                        .font(.headline)
                                    Text(trips.isEmpty
                                        ? "Your completed trips will appear here once logged."
                                        : "Try adjusting your search or filters.")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.4))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 40)
                                .padding(.horizontal, 40)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .frame(height: effectivePanelHeight)
                .background(Color.appBackground)
                .background(.ultraThinMaterial)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .ignoresSafeArea(edges: .bottom)
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

