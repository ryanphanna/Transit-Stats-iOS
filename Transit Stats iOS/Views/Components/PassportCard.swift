import SwiftUI

struct PassportCard: View {
    let year: Int?
    let trips: [TripRecord]
    let totalMinutes: Int
    let uniqueRoutes: Int
    let uniqueStops: Int
    let uniqueDays: Int
    let agencyCount: Int
    let nickname: String
    let joinDate: String
    @EnvironmentObject private var appEnv: AppEnvironment
    private var accent: Color { appEnv.accent }
    
    // Logic for time formatting is in ViewModel, but we can pass formatted string or re-implement if simple
    let formattedTime: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Hero Title
            VStack(alignment: .leading, spacing: 4) {
                Text((year.map { "\($0) " } ?? "ALL-TIME ").uppercased() + "TRANSIT PASSPORT")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(accent)
                    .kerning(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 8))
                    Text("PERSONAL TRANSIT RECORD")
                        .font(.system(size: 8, weight: .black))
                        .kerning(1.5)
                }
                .foregroundColor(.white.opacity(0.4))
            }
            
            // Primary Stats
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TRIPS")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(1)
                    Text("\(trips.count)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(agencyCount) Agencies")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TIME")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(1)
                    Text(formattedTime)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("In transit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Secondary Stats Grid
            HStack(spacing: 0) {
                miniPassportStat(label: "ROUTES", value: "\(uniqueRoutes)")
                miniPassportStat(label: "STOPS", value: "\(uniqueStops)")
                miniPassportStat(label: "DAYS", value: "\(uniqueDays)")
            }
            
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(nickname.uppercased())
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("SINCE \(joinDate)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
                Spacer()
            }
        }
        .padding(24)
        .background(
            ZStack {
                Color(hex: "020617")
                LinearGradient(
                    colors: [accent.opacity(0.15), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
    }

    private func miniPassportStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.white.opacity(0.3))
                .kerning(1)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
