import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftData
import Combine

/// Network client to communicate with the Transit Stats custom HTTP API endpoint.
@MainActor
class TransitStatsAPI: ObservableObject {
    static let shared = TransitStatsAPI()
    
    private let baseURL = URL(string: "https://us-central1-transitstats-21ba4.cloudfunctions.net/api")!
    
    @Published var isSendingCommand = false
    @Published var lastReplies: [String] = []
    @Published var lastError: String? = nil
    
    /// Requests a login OTP code for the given phone number.
    func requestOtp(phoneNumber: String) async throws {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "action": "request_otp",
            "phoneNumber": phoneNumber
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TransitStatsAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }
        
        if httpResponse.statusCode != 200 {
            if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorObj["error"] as? String {
                throw NSError(domain: "TransitStatsAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            throw NSError(domain: "TransitStatsAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to send code (\(httpResponse.statusCode))"])
        }
    }
    
    /// Verifies the OTP code and returns the Firebase Custom Token.
    func verifyOtp(phoneNumber: String, code: String) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "action": "verify_otp",
            "phoneNumber": phoneNumber,
            "code": code
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TransitStatsAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }
        
        if httpResponse.statusCode != 200 {
            if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorObj["error"] as? String {
                throw NSError(domain: "TransitStatsAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            throw NSError(domain: "TransitStatsAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Verification failed (\(httpResponse.statusCode))"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else {
            throw NSError(domain: "TransitStatsAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Response missing token"])
        }
        
        return token
    }
    
    private func getIdToken() async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "TransitStatsAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        return try await currentUser.getIDToken()
    }
    
    /// Sends a text command to the Transit Stats backend, replicating the Twilio SMS flow.
    @discardableResult
    func sendCommand(_ command: String) async -> [String] {
        self.isSendingCommand = true
        self.lastError = nil
        
        defer {
            self.isSendingCommand = false
        }
        
        do {
            let token = try await getIdToken()
            
            var request = URLRequest(url: baseURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = ["command": command]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "TransitStatsAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
            }
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw NSError(domain: "TransitStatsAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Access denied. Whitelist verification failed."])
            }
            
            if httpResponse.statusCode != 200 {
                if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = errorObj["error"] as? String {
                    throw NSError(domain: "TransitStatsAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }
                throw NSError(domain: "TransitStatsAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned error \(httpResponse.statusCode)"])
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
    
    /// Uploads a completed TripRecord directly to Firestore.
    func uploadTrip(_ trip: TripRecord) async throws {
        let db = Firestore.firestore()
        
        let data: [String: Any] = [
            "route": trip.route,
            "direction": trip.direction,
            "agency": trip.agency,
            "startTime": Timestamp(date: trip.startTime),
            "endTime": trip.endTime != nil ? Timestamp(date: trip.endTime!) : NSNull(),
            "startStopCode": trip.startStopCode ?? NSNull(),
            "startStopName": trip.startStopName ?? NSNull(),
            "endStopCode": trip.endStopCode ?? NSNull(),
            "endStopName": trip.endStopName ?? NSNull(),
            "startLatitude": trip.startLatitude ?? NSNull(),
            "startLongitude": trip.startLongitude ?? NSNull(),
            "endLatitude": trip.endLatitude ?? NSNull(),
            "endLongitude": trip.endLongitude ?? NSNull(),
            "startAccuracy": trip.startAccuracy ?? NSNull(),
            "endAccuracy": trip.endAccuracy ?? NSNull(),
            "startHubId": trip.startHubId ?? NSNull(),
            "endHubId": trip.endHubId ?? NSNull(),
            "notes": trip.notes ?? NSNull(),
            "vehicle": trip.vehicle ?? NSNull(),
            "source": trip.source,
            "isPublic": trip.isPublic,
            "timezone": trip.timezone,
            "userId": trip.userId,
            "path": trip.path.map { [
                "lat": $0.lat,
                "lon": $0.lon,
                "timestamp": Timestamp(date: $0.timestamp),
                "speed": $0.speed ?? NSNull()
            ] }
        ]
        
        try await db.collection("trips").document(trip.id).setData(data)
        
        // Update local record status
        trip.isSynced = true
    }
}

/// Synchronization manager that listens to Firestore updates and mirrors them to local SwiftData context.
@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    private var listener: ListenerRegistration?
    
    private let lastSyncKey = "lastTripsSyncTimestamp"
    
    /// Listens to the user's trips in Firestore and synchronizes with local SwiftData
    func startSyncing(modelContext: ModelContext, userId: String) {
        stopSyncing()
        
        let db = Firestore.firestore()
        let lastSync = UserDefaults.standard.double(forKey: lastSyncKey)
        
        // 1. If this is a first-time sync (Power User Hydration)
        if lastSync == 0 {
            performInitialHydration(modelContext: modelContext, userId: userId)
        }
        
        // 2. Setup real-time listener for delta changes
        // We use a slightly overlapping timestamp to ensure no gaps
        let syncThreshold = lastSync > 0 ? Date(timeIntervalSince1970: lastSync - 60) : Date(timeIntervalSince1970: 0)
        
        listener = db.collection("trips")
            .whereField("userId", isEqualTo: userId)
            .whereField("startTime", isGreaterThan: Timestamp(date: syncThreshold))
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot = snapshot else {
                    print("Error listening to Firestore trips: \(error?.localizedDescription ?? "unknown")")
                    return
                }
                
                Task { @MainActor in
                    self?.syncTrips(snapshot.documentChanges, in: modelContext, userId: userId)
                    // Update sync timestamp to now
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self?.lastSyncKey ?? "")
                }
            }
    }
    
    /// Pulls the most recent 50 trips immediately, then fetches everything else.
    private func performInitialHydration(modelContext: ModelContext, userId: String) {
        let db = Firestore.firestore()
        
        // Fetch last 50 for instant UI population
        db.collection("trips")
            .whereField("userId", isEqualTo: userId)
            .orderBy("startTime", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snapshot, error in
                guard let snapshot = snapshot else { return }
                Task { @MainActor in
                    self?.syncTrips(snapshot.documentChanges, in: modelContext, userId: userId)
                    print("Initial hydration (recent 50) complete.")
                    
                    // Now fetch the rest in the background
                    self?.fetchFullHistory(modelContext: modelContext, userId: userId)
                }
            }
    }
    
    private func fetchFullHistory(modelContext: ModelContext, userId: String) {
        let db = Firestore.firestore()
        
        // Fetch everything else
        db.collection("trips")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let snapshot = snapshot else { return }
                Task { @MainActor in
                    self?.syncTrips(snapshot.documentChanges, in: modelContext, userId: userId)
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self?.lastSyncKey ?? "")
                    print("Full history sync complete.")
                }
            }
    }
    
    /// Detaches the snapshot listener
    func stopSyncing() {
        listener?.remove()
        listener = nil
    }
    
    /// Finds local trips that haven't been synced to Firestore and uploads them.
    func syncPendingTrips(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<TripRecord>(
            predicate: #Predicate { $0.isSynced == false && $0.endTime != nil }
        )
        
        do {
            let pendingTrips = try modelContext.fetch(descriptor)
            print("Found \(pendingTrips.count) pending trips to sync.")
            
            for trip in pendingTrips {
                Task {
                    do {
                        try await TransitStatsAPI.shared.uploadTrip(trip)
                        try? modelContext.save()
                        print("Synced pending trip: \(trip.id)")
                    } catch {
                        print("Failed to sync pending trip \(trip.id): \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("Failed to fetch pending trips: \(error.localizedDescription)")
        }
    }
    
    /// Syncs the normalized stops library and Hub metadata from Firestore to local SwiftData.
    func syncStops(modelContext: ModelContext) {
        let db = Firestore.firestore()
        let lastStopSyncKey = "lastStopsSyncTimestamp"
        let lastSync = UserDefaults.standard.double(forKey: lastStopSyncKey)
        
        // If we synced within the last 24 hours, skip to save data/battery
        if lastSync > 0 && (Date().timeIntervalSince1970 - lastSync) < 86400 {
            print("Stops library is up to date (synced < 24h ago).")
            return
        }
        
        // Sync Hubs first
        db.collection("hubs").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            Task { @MainActor in
                for doc in documents {
                    let data = doc.data()
                    let id = doc.documentID
                    let name = data["name"] as? String ?? ""
                    let lat = data["latitude"] as? Double ?? 0
                    let lon = data["longitude"] as? Double ?? 0
                    
                    let descriptor = FetchDescriptor<Hub>(predicate: #Predicate { $0.id == id })
                    let existing = try? modelContext.fetch(descriptor).first
                    
                    if let hub = existing {
                        hub.name = name
                        hub.latitude = lat
                        hub.longitude = lon
                    } else {
                        modelContext.insert(Hub(id: id, name: name, latitude: lat, longitude: lon))
                    }
                }
            }
        }
        
        // Sync Stops
        db.collection("stops").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching stops: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            Task { @MainActor in
                for doc in documents {
                    let data = doc.data()
                    let id = doc.documentID
                    let name = data["name"] as? String ?? ""
                    let code = data["code"] as? String
                    let lat = data["latitude"] as? Double ?? data["lat"] as? Double ?? 0
                    let lon = data["longitude"] as? Double ?? data["lng"] as? Double ?? 0
                    let agencies = data["agencies"] as? [String] ?? []
                    let hubId = data["hubId"] as? String
                    let verified = data["verified"] as? Bool ?? false
                    
                    if lat == 0 || lon == 0 { continue } // Skip stops without coordinates
                    
                    let descriptor = FetchDescriptor<Stop>(predicate: #Predicate { $0.id == id })
                    let existing = try? modelContext.fetch(descriptor).first
                    
                    if let stop = existing {
                        // Only update if the incoming data has coordinates and the local one doesn't,
                        // or if the incoming data is from a trusted source (admin/GTFS).
                        if lat != 0 && lon != 0 {
                            stop.latitude = lat
                            stop.longitude = lon
                        }
                        stop.name = name
                        stop.code = code
                        stop.agencies = agencies
                        stop.hubId = hubId
                        stop.verified = verified
                    } else {
                        let newStop = Stop(id: id, name: name, code: code, latitude: lat, longitude: lon, agencies: agencies, hubId: hubId, verified: verified)
                        modelContext.insert(newStop)
                    }
                }
                try? modelContext.save()
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastStopSyncKey)
                print("Synced \(documents.count) stops to local library.")
            }
        }
    }
    
    /// Syncs the user's profile metadata from Firestore to local SwiftData.
    func syncProfile(modelContext: ModelContext, userId: String) {
        let db = Firestore.firestore()
        db.collection("profiles").document(userId).getDocument { snapshot, error in
            guard let data = snapshot?.data(), snapshot?.exists == true else { return }
            
            Task { @MainActor in
                let nickname = data["nickname"] as? String
                let defaultAgency = data["defaultAgency"] as? String ?? "TTC"
                let isPremium = data["isPremium"] as? Bool ?? false
                let isAdmin = data["isAdmin"] as? Bool ?? false
                let joinedAt = (data["createdAt"] as? Timestamp)?.dateValue()
                
                let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.userId == userId })
                let existing = try? modelContext.fetch(descriptor).first
                
                if let profile = existing {
                    profile.nickname = nickname
                    profile.defaultAgency = defaultAgency
                    profile.isPremium = isPremium
                    profile.isAdmin = isAdmin
                    profile.joinedAt = joinedAt
                } else {
                    let newProfile = UserProfile(userId: userId, nickname: nickname, defaultAgency: defaultAgency, isPremium: isPremium, isAdmin: isAdmin, joinedAt: joinedAt)
                    modelContext.insert(newProfile)
                }
                try? modelContext.save()
                print("Profile synced for user: \(userId)")
            }
        }
        
        // Also sync accuracy stats
        db.collection("predictionAccuracy").document(userId).getDocument { snapshot, error in
            guard let data = snapshot?.data(), snapshot?.exists == true else { return }
            
            Task { @MainActor in
                let total = data["total"] as? Int ?? 0
                let hits = data["hits"] as? Int ?? 0
                let v5Total = data["v5Total"] as? Int ?? 0
                let v5Hits = data["v5Hits"] as? Int ?? 0
                
                let descriptor = FetchDescriptor<PredictionAccuracy>(predicate: #Predicate { $0.userId == userId })
                let existing = try? modelContext.fetch(descriptor).first
                
                if let stats = existing {
                    stats.total = total
                    stats.hits = hits
                    stats.v5Total = v5Total
                    stats.v5Hits = v5Hits
                } else {
                    let newStats = PredictionAccuracy(userId: userId, total: total, hits: hits, v5Total: v5Total, v5Hits: v5Hits)
                    modelContext.insert(newStats)
                }
                try? modelContext.save()
            }
        }
    }
    
    private func syncTrips(_ changes: [DocumentChange], in context: ModelContext, userId: String) {
        for change in changes {
            let doc = change.document
            let id = doc.documentID
            let data = doc.data()
            
            switch change.type {
            case .added, .modified:
                let route = data["route"] as? String ?? ""
                let direction = data["direction"] as? String ?? ""
                let agency = data["agency"] as? String ?? "TTC"
                
                let startTime = (data["startTime"] as? Timestamp)?.dateValue() ?? Date()
                let endTime = (data["endTime"] as? Timestamp)?.dateValue()
                
                let startStopCode = data["startStopCode"] as? String
                let startStopName = data["startStopName"] as? String
                let endStopCode = data["endStopCode"] as? String
                let endStopName = data["endStopName"] as? String
                
                let startLatitude = data["startLatitude"] as? Double
                let startLongitude = data["startLongitude"] as? Double
                let endLatitude = data["endLatitude"] as? Double
                let endLongitude = data["endLongitude"] as? Double
                
                let startAccuracy = data["startAccuracy"] as? Double
                let endAccuracy = data["endAccuracy"] as? Double
                
                let startHubId = data["startHubId"] as? String
                let endHubId = data["endHubId"] as? String
                
                let notes = data["notes"] as? String
                let vehicle = data["vehicle"] as? String
                let source = data["source"] as? String ?? "ios"
                let isPublic = data["isPublic"] as? Bool ?? false
                let timezone = data["timezone"] as? String ?? TimeZone.current.identifier
                
                // Fetch existing SwiftData record
                let descriptor = FetchDescriptor<TripRecord>(predicate: #Predicate { $0.id == id })
                let existing = try? context.fetch(descriptor).first
                
                if let record = existing {
                    record.route = route
                    record.direction = direction
                    record.agency = agency
                    record.startTime = startTime
                    record.endTime = endTime
                    record.startStopCode = startStopCode
                    record.startStopName = startStopName
                    record.endStopCode = endStopCode
                    record.endStopName = endStopName
                    record.startLatitude = startLatitude
                    record.startLongitude = startLongitude
                    record.endLatitude = endLatitude
                    record.endLongitude = endLongitude
                    record.startAccuracy = startAccuracy
                    record.endAccuracy = endAccuracy
                    record.notes = notes
                    record.vehicle = vehicle
                    record.source = source
                    record.isPublic = isPublic
                    record.timezone = timezone
                    record.isSynced = true
                } else {
                    let record = TripRecord(
                        id: id,
                        route: route,
                        direction: direction,
                        agency: agency,
                        startTime: startTime,
                        endTime: endTime,
                        startStopCode: startStopCode,
                        startStopName: startStopName,
                        endStopCode: endStopCode,
                        endStopName: endStopName,
                        startLatitude: startLatitude,
                        startLongitude: startLongitude,
                        endLatitude: endLatitude,
                        endLongitude: endLongitude,
                        startAccuracy: startAccuracy,
                        endAccuracy: endAccuracy,
                        startHubId: startHubId,
                        endHubId: endHubId,
                        notes: notes,
                        vehicle: vehicle,
                        source: source,
                        isPublic: isPublic,
                        timezone: timezone,
                        userId: userId,
                        isSynced: true
                    )
                    context.insert(record)
                }
                
            case .removed:
                let descriptor = FetchDescriptor<TripRecord>(predicate: #Predicate { $0.id == id })
                if let existing = try? context.fetch(descriptor).first {
                    context.delete(existing)
                }
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save synced SwiftData context: \(error.localizedDescription)")
        }
    }
}
  }
}
