import Foundation
import SwiftData

@Model
final class Hub {
    @Attribute(.unique) var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    
    init(id: String, name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}
