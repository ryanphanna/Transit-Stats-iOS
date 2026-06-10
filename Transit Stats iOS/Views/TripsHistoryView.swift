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
            var matchesDate = true
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
            mapBackground
            
            backgroundDimming

            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    panelHeader
                    panelContent
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

    private var mapBackground: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
        }
        .preferredColorScheme(.dark)
        .mapStyle(.standard)
        .mapControls { }
        .ignoresSafeArea()
    }

    private var backgroundDimming: some View {
        Color.black.opacity(min(0.4, Double(effectivePanelHeight - 140) / 1000.0))
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var panelHeader: some View {
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
    }

    private var panelContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                filterRow
                
                if filtered.isEmpty {
                    emptyState
                } else {
                    tripList
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let expanded = expandedFilter {
                    backButton
                    
                    if expanded == "time" {
                        timeFilters
                    } else if expanded == "source" {
                        sourceFilters
                    } else if expanded == "agency" {
                        agencyFilters
                    }
                } else {
                    categoryShortcuts
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var backButton: some View {
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
    }

    private var timeFilters: some View {
        Group {
            filterChip("All time",   active: dateFilter == "all")   { dateFilter = "all";   withAnimation { expandedFilter = nil } }
            filterChip("This week",  active: dateFilter == "week")  { dateFilter = "week";  withAnimation { expandedFilter = nil } }
            filterChip("This month", active: dateFilter == "month") { dateFilter = "month"; withAnimation { expandedFilter = nil } }
            filterChip("This year",  active: dateFilter == "year")  { dateFilter = "year";  withAnimation { expandedFilter = nil } }
        }
    }

    private var sourceFilters: some View {
        Group {
            filterChip("All", active: sourceFilter == "all") { sourceFilter = "all"; withAnimation { expandedFilter = nil } }
            filterChip("App", active: sourceFilter == "app") { sourceFilter = "app"; withAnimation { expandedFilter = nil } }
            filterChip("SMS", active: sourceFilter == "sms") { sourceFilter = "sms"; withAnimation { expandedFilter = nil } }
        }
    }

    private var agencyFilters: some View {
        Group {
            filterChip("All", active: agencyFilter == nil) { agencyFilter = nil; withAnimation { expandedFilter = nil } }
            ForEach(availableAgencies, id: \.self) { agency in
                filterChip(agency, active: agencyFilter == agency) { agencyFilter = agency; withAnimation { expandedFilter = nil } }
            }
        }
    }

    private var categoryShortcuts: some View {
        Group {
            categoryButton(label: dateLabel,  icon: "calendar",  id: "time")
            categoryButton(label: sourceLabel, icon: "iphone",    id: "source")
            categoryButton(label: agencyLabel, icon: "building.2", id: "agency")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.1))
                .padding(.top, 40)
            Text("No trips found")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white.opacity(0.3))
            Text("Try changing your search or filters")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity)
    }

    private var tripList: some View {
        LazyVStack(spacing: 2) {
            ForEach(filtered) { trip in
                TripRow(trip: trip)
                    .onTapGesture { selectedTrip = trip }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var dateLabel: String {
        switch dateFilter {
        case "week":  return "This week"
        case "month": return "This month"
        case "year":  return "This year"
        default:      return "Any time"
        }
    }

    private var sourceLabel: String {
        switch sourceFilter {
        case "sms": return "SMS Only"
        case "app": return "App Only"
        default:    return "Any Source"
        }
    }

    private var agencyLabel: String {
        agencyFilter ?? "Any Agency"
    }

    private func categoryButton(label: String, icon: String, id: String) -> some View {
        Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { expandedFilter = id } }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .opacity(0.4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .foregroundColor(.white.opacity(0.7))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func filterChip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(active ? accent : Color.white.opacity(0.06))
                .foregroundColor(active ? .white : .white.opacity(0.6))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
