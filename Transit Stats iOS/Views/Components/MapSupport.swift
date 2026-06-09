import SwiftUI
import MapKit

// MARK: - Helper Shapes

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - Map Support Types

struct TripMarker: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let count: Int
    let label: String
    let route: String
    var isActive: Bool = false
}

// MARK: - Map Support Views

struct HubView: View {
    let marker: TripMarker
    @EnvironmentObject private var appEnv: AppEnvironment
    private var accent: Color { appEnv.accent }
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            if marker.isActive {
                // Active trip: Glowing pulsing ring
                Circle()
                    .stroke(accent, lineWidth: 2)
                    .frame(width: 36, height: 36)
                    .scaleEffect(isAnimating ? 1.4 : 0.8)
                    .opacity(isAnimating ? 0 : 0.6)
                    .onAppear {
                        withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
                
                Circle()
                    .fill(accent)
                    .frame(width: 28, height: 28)
                    .shadow(color: accent.opacity(0.4), radius: 8, x: 0, y: 4)
                
                Image(systemName: "tram.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            } else {
                // Inactive hub: Heatmap dot with translucent border
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    
                    Circle()
                        .fill(accent)
                        .opacity(heatmapIntensity(for: marker.count))
                        .frame(width: 12, height: 12)
                        .shadow(color: accent.opacity(marker.count > 5 ? 0.4 : 0), radius: 4)
                }
            }
        }
        .scaleEffect(marker.isActive ? 1.1 : scaleForCount(marker.count))
        .animation(.spring(), value: marker.isActive)
    }
    
    private func heatmapIntensity(for count: Int) -> Double {
        min(0.2 + (Double(count) / 15.0) * 0.8, 1.0)
    }
    
    private func scaleForCount(_ count: Int) -> CGFloat {
        min(0.9 + CGFloat(count) * 0.02, 1.3)
    }
}
