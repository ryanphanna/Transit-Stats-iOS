import Foundation
import SwiftData

@Model
final class TripRecord {
    @Attribute(.unique) var id: String
    var route: String
    var direction: String
    var agency: String
    var startTime: Date
    var endTime: Date?
    var startStopCode: String?
    var startStopName: String?
    var endStopCode: String?
    var endStopName: String?
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?
    var notes: String?
    var vehicle: String?
    var source: String
    var isPublic: Bool
    var timezone: String
    var userId: String
    var isSynced: Bool
    
    init(
        id: String = UUID().uuidString,
        route: String,
        direction: String,
        agency: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        startStopCode: String? = nil,
        startStopName: String? = nil,
        endStopCode: String? = nil,
        endStopName: String? = nil,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLatitude: Double? = nil,
        endLongitude: Double? = nil,
        notes: String? = nil,
        vehicle: String? = nil,
        source: String = "ios",
        isPublic: Bool = false,
        timezone: String = TimeZone.current.identifier,
        userId: String = "",
        isSynced: Bool = false
    ) {
        self.id = id
        self.route = route
        self.direction = direction
        self.agency = agency
        self.startTime = startTime
        self.endTime = endTime
        self.startStopCode = startStopCode
        self.startStopName = startStopName
        self.endStopCode = endStopCode
        self.endStopName = endStopName
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.notes = notes
        self.vehicle = vehicle
        self.source = source
        self.isPublic = isPublic
        self.timezone = timezone
        self.userId = userId
        self.isSynced = isSynced
    }
    
    var durationMinutes: Int? {
        guard let endTime = endTime else { return nil }
        return Int(endTime.timeIntervalSince(startTime) / 60)
    }
}
