import Foundation
import SwiftData

@Model
final class PredictionAccuracy {
    @Attribute(.unique) var userId: String
    var total: Int
    var hits: Int
    var v5Total: Int
    var v5Hits: Int
    
    init(userId: String, total: Int = 0, hits: Int = 0, v5Total: Int = 0, v5Hits: Int = 0) {
        self.userId = userId
        self.total = total
        self.hits = hits
        self.v5Total = v5Total
        self.v5Hits = v5Hits
    }
    
    var v5Accuracy: Double {
        guard v5Total > 0 else { return 0 }
        return Double(v5Hits) / Double(v5Total)
    }
}
