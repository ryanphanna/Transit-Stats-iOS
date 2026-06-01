import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TripRecord.startTime, order: .reverse) private var trips: [TripRecord]
    
    var body: some View {
        ZStack {
            Color(hex: "020617").ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transit Card")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Your transit career at a glance.")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.2))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // The Transit Card
                    TransitCard(trips: trips)
                    
                    // Detailed Stats
                    VStack(spacing: 16) {
                        statRow(label: "Total Trips", value: "\(trips.count)", icon: "tram.fill", color: .blue)
                        statRow(label: "Unique Routes", value: "\(uniqueRoutesCount())", icon: "map.fill", color: .orange)
                        statRow(label: "Unique Stops", value: "\(uniqueStopsCount())", icon: "mappin.and.ellipse", color: .green)
                        statRow(label: "Transit Rank", value: calculateRank(), icon: "star.fill", color: .yellow)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 50)
                }
            }
        }
    }
    
    private func uniqueRoutesCount() -> Int {
        Set(trips.map { $0.route }).count
    }
    
    private func uniqueStopsCount() -> Int {
        Set(trips.compactMap { $0.startStopName ?? $0.startStopCode }).count
    }
    
    private func calculateRank() -> String {
        let count = trips.count
        if count < 10 { return "New Rider" }
        if count < 50 { return "Regular" }
        if count < 200 { return "Pro Commuter" }
        if count < 500 { return "Transit Expert" }
        return "System Master"
    }
    
    private func statRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: icon).foregroundColor(color).font(.system(size: 16, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.4))
                Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.white)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct TransitCard: View {
    let trips: [TripRecord]
    
    var body: some View {
        ZStack {
            // Card Background with Mesh Gradient-like effect
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: [Color(hex: "1e293b"), Color(hex: "0f172a")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 220)
                .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 10)
            
            // Holographic Overlay (Simulated)
            RoundedRectangle(cornerRadius: 24)
                .stroke(LinearGradient(
                    colors: [.white.opacity(0.4), .clear, .white.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "tram.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text("TRANSIT STATS")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                        .kerning(1.5)
                    Spacer()
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(Text("T").font(.system(size: 16, weight: .bold)).foregroundColor(.orange))
                }
                .padding(24)
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SYSTEM MEMBER SINCE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text(joinDate())
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("TOP ROUTE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text(topRoute())
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }
                .padding(24)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func joinDate() -> String {
        guard let first = trips.last else { return "MAY 2026" }
        return first.startTime.formatted(.dateTime.month().year()).uppercased()
    }
    
    private func topRoute() -> String {
        let routes = trips.map { $0.route }
        let counts = routes.reduce(into: [:]) { counts, route in counts[route, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key ?? "N/A"
    }
}

#Preview {
    ProfileView()
}
