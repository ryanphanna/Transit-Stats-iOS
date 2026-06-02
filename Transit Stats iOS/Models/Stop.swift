import Foundation
import SwiftData

@Model
final class Stop {
    @Attribute(.unique) var id: String
    var name: String
    var code: String?
    var latitude: Double
    var longitude: Double
    var agencies: [String]
    var hubId: String?
    var verified: Bool
    var lastUsed: Date?
    
    init(id: String, name: String, code: String? = nil, latitude: Double, longitude: Double, agencies: [String] = [], hubId: String? = nil, verified: Bool = false) {
        self.id = id
        self.name = name
        self.code = code
        self.latitude = latitude
        self.longitude = longitude
        self.agencies = agencies
        self.hubId = hubId
        self.verified = verified
        self.lastUsed = Date()
    }
}
