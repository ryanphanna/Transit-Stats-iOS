import Foundation
import FirebaseFirestore
import SwiftData
import Combine

@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    private var listener: ListenerRegistration?
    private let lastSyncKey = "lastTripsSyncTimestamp"
    
    private init() {}
    
    func startSyncing(modelContext: ModelContext, userId: String) {
        stopSyncing()
        
        let db = Firestore.firestore()
        let lastSync = UserDefaults.standard.double(forKey: lastSyncKey)
        
        // 1. If this is a first-time sync (Initial Hydration)
        if lastSync == 0 {
            performInitialHydration(modelContext: modelContext, userId: userId)
        }
        
        // 2. Setup real-time listener for delta changes
        listener = db.collection("trips")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot = snapshot else {
                    print("Error listening to Firestore trips: \(error?.localizedDescription ?? "unknown")")
                    return
                }
                
                Task { @MainActor in
                    guard let self = self else { return }
                    self.syncTrips(snapshot.documentChanges, in: modelContext, userId: userId)
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastSyncKey)
                }
            }
    }
    
    func stopSyncing() {
        listener?.remove()
        listener = nil
    }
    
    private func performInitialHydration(modelContext: ModelContext, userId: String) {
        let db = Firestore.firestore()
        
        // Fetch last 50 for instant UI population
        db.collection("trips")
            .whereField("userId", isEqualTo: userId)
            .order(by: "startTime", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snapshot, error in
                guard let snapshot = snapshot else { return }
                Task { @MainActor in
                    guard let self = self else { return }
                    self.syncTrips(snapshot.documentChanges, in: modelContext, userId: userId)
                    print("Initial hydration (recent 50) complete.")
                    self.fetchFullHistory(modelContext: modelContext, userId: userId)
                }
            }
    }
    
    private func fetchFullHistory(modelContext: ModelContext, userId: String) {
        let db = Firestore.firestore()
        db.collection("trips")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let snapshot = snapshot else { return }
                Task { @MainActor in
                    guard let self = self else { return }
                    self.syncTrips(snapshot.documentChanges, in: modelContext, userId: userId)
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastSyncKey)
                    print("Full history sync complete.")
                }
            }
    }
    
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
                        try await TripService.shared.uploadTrip(trip)
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
    
    func syncStops(modelContext: ModelContext) {
        let db = Firestore.firestore()
        let lastStopSyncKey = "lastStopsSyncTimestamp"
        let lastSync = UserDefaults.standard.double(forKey: lastStopSyncKey)
        
        if lastSync > 0 && (Date().timeIntervalSince1970 - lastSync) < 86400 {
            print("Stops library is up to date.")
            return
        }
        
        // Sync Hubs
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
                    if let hub = try? modelContext.fetch(descriptor).first {
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
            guard let documents = snapshot?.documents else { return }
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
                    
                    if lat == 0 || lon == 0 { continue }
                    
                    let descriptor = FetchDescriptor<Stop>(predicate: #Predicate { $0.id == id })
                    if let stop = try? modelContext.fetch(descriptor).first {
                        stop.name = name
                        stop.code = code
                        stop.latitude = lat
                        stop.longitude = lon
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
                print("Synced \(documents.count) stops.")
            }
        }
    }
    
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
                if let profile = try? modelContext.fetch(descriptor).first {
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
            }
        }
        
        db.collection("predictionAccuracy").document(userId).getDocument { snapshot, error in
            guard let data = snapshot?.data(), snapshot?.exists == true else { return }
            Task { @MainActor in
                let descriptor = FetchDescriptor<PredictionAccuracy>(predicate: #Predicate { $0.userId == userId })
                if let stats = try? modelContext.fetch(descriptor).first {
                    stats.total = data["total"] as? Int ?? 0
                    stats.hits = data["hits"] as? Int ?? 0
                    stats.v5Total = data["v5Total"] as? Int ?? 0
                    stats.v5Hits = data["v5Hits"] as? Int ?? 0
                } else {
                    let newStats = PredictionAccuracy(userId: userId, 
                                                     total: data["total"] as? Int ?? 0, 
                                                     hits: data["hits"] as? Int ?? 0, 
                                                     v5Total: data["v5Total"] as? Int ?? 0, 
                                                     v5Hits: data["v5Hits"] as? Int ?? 0)
                    modelContext.insert(newStats)
                }
                try? modelContext.save()
            }
        }
    }
    
    private func syncTrips(_ changes: [DocumentChange], in context: ModelContext, userId: String) {
        for change in changes {
            let id = change.document.documentID
            let data = change.document.data()
            
            switch change.type {
            case .added, .modified:
                let descriptor = FetchDescriptor<TripRecord>(predicate: #Predicate { $0.id == id })
                if let record = try? context.fetch(descriptor).first {
                    updateTripRecord(record, with: data)
                } else {
                    let record = TripRecord(id: id, 
                                          route: data["route"] as? String ?? "", 
                                          direction: data["direction"] as? String ?? "", 
                                          agency: data["agency"] as? String ?? "TTC", 
                                          startTime: (data["startTime"] as? Timestamp)?.dateValue() ?? Date(), 
                                          userId: userId, 
                                          isSynced: true)
                    updateTripRecord(record, with: data)
                    context.insert(record)
                }
            case .removed:
                let descriptor = FetchDescriptor<TripRecord>(predicate: #Predicate { $0.id == id })
                if let existing = try? context.fetch(descriptor).first {
                    context.delete(existing)
                }
            }
        }
        try? context.save()
    }
    
    private func updateTripRecord(_ record: TripRecord, with data: [String: Any]) {
        record.route = data["route"] as? String ?? ""
        record.direction = data["direction"] as? String ?? ""
        record.agency = data["agency"] as? String ?? "TTC"
        record.startTime = (data["startTime"] as? Timestamp)?.dateValue() ?? Date()
        record.endTime = (data["endTime"] as? Timestamp)?.dateValue()
        record.startStopCode = data["startStopCode"] as? String
        record.startStopName = data["startStopName"] as? String
        record.endStopCode = data["endStopCode"] as? String
        record.endStopName = data["endStopName"] as? String
        record.startLatitude = data["startLatitude"] as? Double
        record.startLongitude = data["startLongitude"] as? Double
        record.endLatitude = data["endLatitude"] as? Double
        record.endLongitude = data["endLongitude"] as? Double
        record.startAccuracy = data["startAccuracy"] as? Double
        record.endAccuracy = data["endAccuracy"] as? Double
        record.notes = data["notes"] as? String
        record.vehicle = data["vehicle"] as? String
        record.source = data["source"] as? String ?? "ios"
        record.isPublic = data["isPublic"] as? Bool ?? false
        record.timezone = data["timezone"] as? String ?? TimeZone.current.identifier
        record.journeyId = data["journeyId"] as? String
        record.isSynced = true
        
        if let pathData = data["path"] as? [[String: Any]] {
            let points: [TripPathPoint] = pathData.compactMap { dict in
                guard let lat = dict["lat"] as? Double,
                      let lon = dict["lon"] as? Double,
                      let ts = (dict["timestamp"] as? Timestamp)?.dateValue() else { return nil }
                return TripPathPoint(lat: lat, lon: lon, timestamp: ts, speed: dict["speed"] as? Double)
            }
            record.pathData = try? JSONEncoder().encode(points)
        }
    }
}
