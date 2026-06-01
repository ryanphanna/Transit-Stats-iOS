import SwiftUI

struct AddTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var locationManager = LocationManager.shared

    // Step 1: waiting at stop
    @State private var stopText = ""

    // Step 2: boarded — enter route
    @State private var routeText = ""
    @State private var agency = "TTC"
    @State private var direction = ""

    @State private var step: BoardingStep = .atStop
    @State private var isLoading = false

    // Timestamp when the user first taps "I'm at the stop"
    @State private var waitingSince: Date? = nil

    enum BoardingStep {
        case atStop, onBoard
    }

    let agencies = ["TTC", "GO", "UP Express", "VIA Rail", "YRT", "MiWay", "HSR"]

    var body: some View {
        ZStack {
            Color(hex: "0a0f1e").ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 5)
                    .padding(.top, 14)
                    .padding(.bottom, 20)

                // Progress indicator
                HStack(spacing: 8) {
                    stepDot(label: "WAITING", active: step == .atStop, done: step == .onBoard)
                    Rectangle()
                        .fill(step == .onBoard ? Color.orange : Color.white.opacity(0.12))
                        .frame(height: 1)
                        .animation(.easeInOut(duration: 0.4), value: step)
                    stepDot(label: "BOARDED", active: step == .onBoard, done: false)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

                // Step content
                Group {
                    if step == .atStop {
                        atStopView
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        onBoardView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: step)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
        }
        .onDisappear {
            locationManager.stopUpdating()
        }
    }

    // MARK: - Step Views

    private var atStopView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Where are you waiting?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Enter the stop name or number. We'll log the timestamp now.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.45))
                    .lineSpacing(2)
            }
            .padding(.horizontal, 28)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("STOP")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                        .kerning(1.2)
                        .padding(.horizontal, 28)

                    TextField("e.g. College St at Spadina", text: $stopText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    stopText.isEmpty ? Color.white.opacity(0.1) : Color.orange.opacity(0.4),
                                    lineWidth: 1
                                )
                        )
                        .padding(.horizontal, 20)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { advanceToBoard() }
                }

                // Current time display
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.3))
                    Text("Arrival logged at \(Date().formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.3))
                }
                .padding(.horizontal, 28)
                .padding(.top, 2)
            }

            // Primary CTA
            Button(action: advanceToBoard) {
                HStack {
                    Spacer()
                    Text("I'm at the stop")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(
                    stopText.isEmpty
                        ? AnyShapeStyle(Color.white.opacity(0.06))
                        : AnyShapeStyle(LinearGradient(colors: [Color.orange, Color(hex: "ff6b35")], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(stopText.isEmpty ? Color.white.opacity(0.25) : .white)
                .cornerRadius(14)
                .shadow(color: stopText.isEmpty ? .clear : Color.orange.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(stopText.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 20)
            .animation(.easeInOut(duration: 0.2), value: stopText.isEmpty)

            // Skip stop — just go straight to boarding
            Button(action: {
                withAnimation { step = .onBoard }
                waitingSince = Date()
            }) {
                Text("Skip — I'm already on board")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private var onBoardView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                    Text("You're on board!")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.orange)
                        .kerning(1)
                }

                Text("Which route did you board?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 2)

                if !stopText.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.35))
                        Text(stopText)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                }
            }
            .padding(.horizontal, 28)

            VStack(spacing: 14) {
                // Route input
                VStack(alignment: .leading, spacing: 6) {
                    Text("ROUTE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                        .kerning(1.2)
                        .padding(.horizontal, 28)

                    TextField("e.g. 506, Line 1, GO Lakeshore", text: $routeText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    routeText.isEmpty ? Color.white.opacity(0.1) : Color.orange.opacity(0.5),
                                    lineWidth: 1
                                )
                        )
                        .padding(.horizontal, 20)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { if !routeText.isEmpty { submitTrip() } }
                }

                // Agency picker — compact chips
                VStack(alignment: .leading, spacing: 8) {
                    Text("AGENCY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                        .kerning(1.2)
                        .padding(.horizontal, 28)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(agencies, id: \.self) { ag in
                                Button(action: { agency = ag }) {
                                    Text(ag)
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(agency == ag ? Color.orange : Color.white.opacity(0.07))
                                        .foregroundColor(agency == ag ? .white : Color.white.opacity(0.5))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(agency == ag ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                }
                                .animation(.easeInOut(duration: 0.15), value: agency)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }

            // Start Trip CTA
            Button(action: submitTrip) {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 14))
                        Text("Start Trip")
                            .font(.system(size: 15, weight: .bold))
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(
                    routeText.isEmpty
                        ? AnyShapeStyle(Color.white.opacity(0.06))
                        : AnyShapeStyle(LinearGradient(colors: [Color.orange, Color(hex: "ff6b35")], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(routeText.isEmpty ? Color.white.opacity(0.25) : .white)
                .cornerRadius(14)
                .shadow(color: routeText.isEmpty ? .clear : Color.orange.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(isLoading || routeText.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 20)
            .animation(.easeInOut(duration: 0.2), value: routeText.isEmpty)

            // Back button
            Button(action: { withAnimation { step = .atStop } }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11))
                    Text("Back")
                        .font(.system(size: 12))
                }
                .foregroundColor(Color.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    // MARK: - Step Indicator

    private func stepDot(label: String, active: Bool, done: Bool) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(done || active ? Color.orange : Color.white.opacity(0.1))
                    .frame(width: 10, height: 10)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 6, weight: .black))
                        .foregroundColor(.white)
                }
            }
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(active ? .orange : Color.white.opacity(0.3))
                .kerning(0.8)
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Actions

    private func advanceToBoard() {
        guard !stopText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        waitingSince = Date()
        withAnimation { step = .onBoard }
    }

    private func submitTrip() {
        let route = routeText.trimmingCharacters(in: .whitespaces)
        guard !route.isEmpty else { return }
        
        guard let userId = authManager.currentUser?.uid else {
            print("Error: No user logged in")
            return
        }

        isLoading = true

        let stop = stopText.trimmingCharacters(in: .whitespaces)
        
        let newTrip = TripRecord(
            route: route,
            direction: direction,
            agency: agency,
            startTime: waitingSince ?? Date(),
            startStopName: stop.isEmpty ? nil : stop,
            startLatitude: locationManager.lastLocation?.coordinate.latitude,
            startLongitude: locationManager.lastLocation?.coordinate.longitude,
            userId: userId,
            isSynced: false
        )
        
        modelContext.insert(newTrip)
        
        do {
            try modelContext.save()
            isLoading = false
            dismiss()
        } catch {
            print("Failed to save local trip: \(error.localizedDescription)")
            isLoading = false
        }
    }
}

#Preview {
    AddTripView()
}
