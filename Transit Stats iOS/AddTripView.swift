import SwiftUI

struct AddTripView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var api = TransitStatsAPI.shared
    
    @State private var route = ""
    @State private var direction = "Northbound"
    @State private var startStop = ""
    @State private var agency = "TTC"
    @State private var vehicle = ""
    @State private var notes = ""
    @State private var isLoading = false
    
    let directions = ["Northbound", "Southbound", "Eastbound", "Westbound", "Clockwise", "Counterclockwise", "Inbound", "Outbound", "None"]
    let agencies = ["TTC", "GO", "UP Express", "VIA Rail", "YRT", "MiWay", "HSR"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Route Information") {
                    TextField("Route Number or Name (e.g. 506, Line 1)", text: $route)
                        .autocorrectionDisabled()
                    
                    Picker("Direction", selection: $direction) {
                        ForEach(directions, id: \.self) { dir in
                            Text(dir).tag(dir)
                        }
                    }
                    
                    Picker("Transit Agency", selection: $agency) {
                        ForEach(agencies, id: \.self) { ag in
                            Text(ag).tag(ag)
                        }
                    }
                }
                
                Section("Boarding Details") {
                    TextField("Start Stop Code or Name (e.g. College Station)", text: $startStop)
                        .autocorrectionDisabled()
                    
                    TextField("Vehicle Code / Name (Optional)", text: $vehicle)
                        .autocorrectionDisabled()
                        .keyboardType(.numberPad)
                }
                
                Section("Additional Notes") {
                    TextField("Notes (Optional)", text: $notes)
                }
                
                Section {
                    Button(action: submitTrip) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Start Trip")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || route.isEmpty || startStop.isEmpty)
                    .foregroundColor(.white)
                    .listRowBackground(
                        route.isEmpty || startStop.isEmpty ? Color.gray.opacity(0.3) : Color.blue
                    )
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitTrip() {
        isLoading = true
        
        // Compile the inputs into a structured command line.
        // e.g. "506 College Station Westbound" or with vehicle/notes prefix or suffix
        var parts: [String] = []
        
        parts.append(route)
        parts.append(startStop)
        
        if direction != "None" {
            parts.append(direction)
        }
        
        if !vehicle.isEmpty {
            // Check dispatcher format for vehicle: usually "506 College Westbound vehicle 4401"
            parts.append("vehicle \(vehicle)")
        }
        
        if !notes.isEmpty {
            parts.append("notes \(notes)")
        }
        
        let command = parts.joined(separator: " ")
        
        Task {
            await api.sendCommand(command)
            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    AddTripView()
}
