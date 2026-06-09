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
    @State private var expandedFilter: String? = nil
    
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
            Color.black.opacity(min(0.4, Double(effectivePanelHeight - 140) / 1000.0))
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
                            // Filter row — category view OR drill-down options
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if let expanded = expandedFilter {
                                        // Back button
                                        Button(action: { withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { expandedFilter = nil } }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white.opacity(0.6))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .background(Color.white.opacity(0.08))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)

                                        if expanded == "time" {
                                            filterChip("All time",   active: dateFilter == "all")   { dateFilter = "all";   withAnimation { expandedFilter = nil } }
                                            filterChip("This week",  active: dateFilter == "week")  { dateFilter = "week";  withAnimation { expandedFilter = nil } }
                                            filterChip("This month", active: dateFilter == "month") { dateFilter = "month"; withAnimation { expandedFilter = nil } }
                                            filterChip("This year",  active: dateFilter == "year")  { dateFilter = "year";  withAnimation { expandedFilter = nil } }
                                        } else if expanded == "source" {
                                            filterChip("All", active: sourceFilter == "all") { sourceFilter = "all"; withAnimation { expandedFilter = nil } }
                                            filterChip("App", active: sourceFilter == "app") { sourceFilter = "app"; withAnimation { expandedFilter = nil } }
                                            filterChip("SMS", active: sourceFilter == "sms") { sourceFilter = "sms"; withAnimation { expandedFilter = nil } }
                                        } else if expanded == "agency" {
                                            filterChip("All", active: agencyFilter == nil) { agencyFilter = nil; withAnimation { expandedFilter = nil } }
                                            ForEach(availableAgencies, id: \.self) { agency in
                                                filterChip(agency, active: agencyFilter == agency) {
                                                    agencyFilter = agencyFilter == agency ? nil : agency
                                                    withAnimation { expandedFilter = nil }
                                                }
                                            }
                                        }
                                    } else {
                                        // Category pills
                                        filterCategory("Time",   isFiltered: dateFilter != "all",   isExpanded: false) { withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { expandedFilter = "time" } }
                                        filterCategory("Source", isFiltered: sourceFilter != "all", isExpanded: false) { withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { expandedFilter = "source" } }
                                        if !availableAgencies.isEmpty {
                                            filterCategory("Agency", isFiltered: agencyFilter != nil, isExpanded: false) { withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { expandedFilter = "agency" } }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .animation(.spring(response: 0.28, dampingFraction: 0.8), value: expandedFilter)
                            }
                            .padding(.vertical, 4)

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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func deleteTrip(_ trip: TripRecord) {
        withAnimation {
            modelContext.delete(trip)
            try? modelContext.save()
        }
    }

    private func filterCategory(_ label: String, isFiltered: Bool, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isFiltered {
                    Circle()
                        .fill(accent)
                        .frame(width: 5, height: 5)
                }
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isExpanded ? .white : (isFiltered ? accent : .white.opacity(0.6)))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isExpanded ? Color.white.opacity(0.1) : (isFiltered ? accent.opacity(0.1) : Color.white.opacity(0.06)))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isFiltered ? accent.opacity(0.25) : Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
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

