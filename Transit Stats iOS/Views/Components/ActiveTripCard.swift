import SwiftUI
import SwiftData
import Combine

struct ActiveTripCard: View {
    let trip: TripRecord
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var tripService: TripService
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appEnv: AppEnvironment
    
    // @Query results need to be passed in from HomeView
    let completedTrips: [TripRecord]
    
    private var accent: Color { appEnv.accent }
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            // Status Row
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.55))
                        .frame(width: 6, height: 6)
                    Text("In Transit")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.55))
                        .kerning(0.5)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 0.2, green: 0.85, blue: 0.55).opacity(0.12))
                .cornerRadius(20)
                
                Spacer()
                
                Text(trip.agency)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
                    .kerning(1)
            }
            
            // Route Header
            if trip.route.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Which route?")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Enter or select below")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("ELAPSED")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.3))
                                .kerning(1)
                            Text(viewModel.timeElapsed)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(accent)
                        }
                    }
                    
                    HStack(spacing: 10) {
                        TextField("e.g. 506, Line 1, GO Lakeshore", text: $viewModel.activeRouteText)
                            .font(.system(size: 14, weight: .medium))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .autocorrectionDisabled()
                        
                        Button(action: {
                            let enteredRoute = viewModel.activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !enteredRoute.isEmpty {
                                withAnimation {
                                    trip.route = enteredRoute
                                    let preds = PredictionEngine.predict(history: completedTrips, stopName: trip.startStopName)
                                        .filter { $0.route.lowercased() == enteredRoute.lowercased() }
                                    if let best = preds.first {
                                        trip.direction = best.direction
                                    }
                                    if let match = completedTrips.first(where: { $0.route.lowercased() == enteredRoute.lowercased() }) {
                                        trip.agency = match.agency
                                    }
                                    try? modelContext.save()
                                    viewModel.activeRouteText = ""
                                }
                            }
                        }) {
                            Text("Apply")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(viewModel.activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.06) : accent)
                                .foregroundColor(viewModel.activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.3) : .white)
                                .cornerRadius(12)
                        }
                        .disabled(viewModel.activeRouteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    let routeSuggestions = PredictionEngine.predict(history: completedTrips, stopName: trip.startStopName).filter { !$0.route.isEmpty }
                    if !routeSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(routeSuggestions.prefix(5), id: \.route) { pred in
                                    Button(action: {
                                        withAnimation {
                                            trip.route = pred.route
                                            trip.direction = pred.direction
                                            if let match = completedTrips.first(where: { $0.route == pred.route }) {
                                                trip.agency = match.agency
                                            }
                                            try? modelContext.save()
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(pred.route)
                                                .font(.system(size: 18, weight: .black, design: .rounded))
                                                .foregroundColor(accent)
                                            if !pred.direction.isEmpty {
                                                Text(pred.direction.uppercased())
                                                    .font(.system(size: 9, weight: .black))
                                                    .foregroundColor(.white.opacity(0.4))
                                                    .kerning(0.5)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(accent.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.route)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        if !trip.direction.isEmpty {
                            Text(trip.direction.uppercased())
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.white.opacity(0.4))
                                .kerning(0.8)
                        }
                    }
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ELAPSED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                            .kerning(1)
                        Text(viewModel.timeElapsed)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(accent)
                    }
                }
            }

            // Timeline
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Origin")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    Text(trip.startStopName ?? trip.startStopCode ?? "Unknown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 6) {
                    Circle().fill(accent).frame(width: 5, height: 5)
                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4]))
                        .frame(height: 1)
                        .foregroundColor(.white.opacity(0.15))
                    Image(systemName: "tram.fill")
                        .font(.system(size: 12))
                        .foregroundColor(accent)
                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4]))
                        .frame(height: 1)
                        .foregroundColor(.white.opacity(0.15))
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 5, height: 5)
                }
                .frame(width: 80)
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Destination")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    Text(viewModel.endStopText.isEmpty ? "..." : viewModel.endStopText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(viewModel.endStopText.isEmpty ? .white.opacity(0.2) : .white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 8)
            
            Divider().background(Color.white.opacity(0.06))
            
            // End trip input
            VStack(spacing: 12) {
                TextField("Enter exit stop name or code", text: $viewModel.endStopText)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                let exitSuggestions = PredictionEngine.predictExitStops(history: completedTrips, route: trip.route, startStopName: trip.startStopName)
                if !exitSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(exitSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    viewModel.endStopText = suggestion
                                    viewModel.endTrip(activeTrip: trip)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.system(size: 9))
                                            .foregroundColor(.white.opacity(0.6))
                                        Text(suggestion)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                
                HStack(spacing: 12) {
                    Button(action: { viewModel.endTrip(activeTrip: trip) }) {
                        HStack {
                            Spacer()
                            if tripService.isSendingCommand {
                                ProgressView().tint(.white)
                            } else {
                                Text("COMPLETE JOURNEY")
                                    .font(.system(size: 12, weight: .black))
                                    .kerning(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(trip.route.isEmpty ? Color.white.opacity(0.08) : accent)
                        .foregroundColor(trip.route.isEmpty ? Color.white.opacity(0.3) : .white)
                        .cornerRadius(12)
                        .shadow(color: trip.route.isEmpty ? .clear : accent.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .disabled(tripService.isSendingCommand || trip.route.isEmpty)
                    
                    Menu {
                        Button("Forgot to End", role: .none, action: { viewModel.forgotTrip(activeTrip: trip) })
                        Button("Discard Trip", role: .destructive, action: { viewModel.discardTrip(activeTrip: trip) })
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 48, height: 48)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(24)
        .onAppear { viewModel.updateTimer(for: trip) }
        .onReceive(timer) { _ in viewModel.updateTimer(for: trip) }
    }
}
