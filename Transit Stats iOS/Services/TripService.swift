import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftData

@MainActor
class TripService: ObservableObject {
    static let shared = TripService()
    
    private let baseURL = URL(string: "https://us-central1-transitstats-21ba4.cloudfunctions.net/api")!
    
    @Published var isSendingCommand = false
    @Published var lastReplies: [String] = []
    @Published var lastError: String? = nil
    
    private init() {}

    @discardableResult
    func sendCommand(_ command: String) async -> [String] {
        self.isSendingCommand = true
        self.lastError = nil
        
        defer {
            self.isSendingCommand = false
        }
        
        do {
            let token = try await AuthService.shared.getIdToken()
            
            var request = URLRequest(url: baseURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = ["command": command]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "TripService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
            }
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw NSError(domain: "TripService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Access denied. Whitelist verification failed."])
            }
            
            if httpResponse.statusCode != 200 {
                if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = errorObj["error"] as? String {
                    throw NSError(domain: "TripService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }
                throw NSError(domain: "TripService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned error \(httpResponse.statusCode)"])
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let replies = json["replies"] as? [String] else {
                return ["Trip logged successfully."]
            }
            
            self.lastReplies = replies
            return replies
            
        } catch {
            let errorMsg = error.localizedDescription
            self.lastError = errorMsg
            return ["Error: \(errorMsg)"]
        }
    }
    
    func deleteTrip(_ tripId: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("trips").document(tripId).delete()
    }

    private func nullable<T>(_ value: T?) -> Any {
        value.map { $0 as Any } ?? NSNull()
    }

    func uploadTrip(_ trip: TripRecord) async throws {
        let db = Firestore.firestore()

        let data: [String: Any] = [
            "route": trip.route,
            "direction": trip.direction,
            "agency": trip.agency,
            "startTime": Timestamp(date: trip.startTime),
            "endTime": trip.endTime.map { Timestamp(date: $0) } ?? NSNull(),
            "startStopCode": nullable(trip.startStopCode),
            "startStopName": nullable(trip.startStopName),
            "endStopCode": nullable(trip.endStopCode),
            "endStopName": nullable(trip.endStopName),
            "startLatitude": nullable(trip.startLatitude),
            "startLongitude": nullable(trip.startLongitude),
            "endLatitude": nullable(trip.endLatitude),
            "endLongitude": nullable(trip.endLongitude),
            "startAccuracy": nullable(trip.startAccuracy),
            "endAccuracy": nullable(trip.endAccuracy),
            "notes": nullable(trip.notes),
            "vehicle": nullable(trip.vehicle),
            "source": trip.source,
            "isPublic": trip.isPublic,
            "timezone": trip.timezone,
            "userId": trip.userId,
            "path": trip.path.map { [
                "lat": $0.lat,
                "lon": $0.lon,
                "timestamp": Timestamp(date: $0.timestamp),
                "speed": nullable($0.speed)
            ] }
        ]
        
        try await db.collection("trips").document(trip.id).setData(data)
        trip.isSynced = true
    }
}
