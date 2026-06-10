import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    @Binding var isShowingGoSheet: Bool
    @EnvironmentObject private var appEnv: AppEnvironment
    private var accent: Color { appEnv.accent }

    var body: some View {
        HStack(spacing: 0) {
            // Trips Tab
            tabButton(index: 0, icon: "clock.fill", label: "Trips")
            
            // Explore Tab
            tabButton(index: 1, icon: "map.fill", label: "Explore")
            
            // Liquid Glass GO Button
            Button(action: { 
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                isShowingGoSheet = true 
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Circle()
                            .stroke(accent.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "tram.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(accent)
                    }
                    Text("GO")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(accent)
                        .kerning(1)
                }
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            
            // Stats Tab
            tabButton(index: 2, icon: "chart.bar.fill", label: "Stats")
            
            // Settings/More (Optional, for symmetry)
            tabButton(index: 3, icon: "gearshape.fill", label: "Settings")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func tabButton(index: Int, icon: String, label: String) -> some View {
        Button(action: { 
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedTab = index 
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(selectedTab == index ? accent : .white.opacity(0.4))
                Text(label)
                    .font(.system(size: 10, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? accent : .white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
