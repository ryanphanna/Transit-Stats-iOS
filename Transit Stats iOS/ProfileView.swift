import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TripRecord.startTime, order: .reverse) private var trips: [TripRecord]
    @Query private var profiles: [UserProfile]
    @Query private var accuracies: [PredictionAccuracy]
    
    private var profile: UserProfile? { profiles.first }
    private var stats: PredictionAccuracy? { accuracies.first }
    
    var body: some View {
        ZStack {
            Color(hex: "020617").ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile?.nickname ?? "Transit Card")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(profile?.isPremium == true ? "Premium System Member" : "Your transit career at a glance.")
                                .font(.system(size: 14))
                                .foregroundColor(profile?.isPremium == true ? .orange : .white.opacity(0.5))
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
                    TransitCard(trips: trips, profile: profile)
                    
                    // Detailed Stats
                    VStack(spacing: 16) {
                        statRow(label: "Total Trips", value: "\(trips.count)", icon: "tram.fill", color: .blue)
                        statRow(label: "Unique Routes", value: "\(uniqueRoutesCount())", icon: "map.fill", color: .orange)
                        
                        if let v5Acc = stats?.v5Accuracy, v5Acc > 0 {
                            statRow(label: "AI Accuracy", value: String(format: "%.1f%%", v5Acc * 100), icon: "brain.head.profile", color: .purple)
                        }
                        
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
    let profile: UserProfile?
    
    var body: some View {
        ZStack {
            // Card Background with Mesh Gradient-like effect
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: [profile?.isPremium == true ? Color(hex: "4338ca") : Color(hex: "1e293b"), Color(hex: "0f172a")],
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
                        .overlay(Text(profile?.nickname?.prefix(1).uppercased() ?? "T").font(.system(size: 16, weight: .bold)).foregroundColor(.orange))
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
        let date = profile?.joinedAt ?? trips.last?.startTime ?? Date()
        return date.formatted(.dateTime.month().year()).uppercased()
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
