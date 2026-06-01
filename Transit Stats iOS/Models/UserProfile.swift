import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var userId: String
    var nickname: String?
    var defaultAgency: String
    var isPremium: Bool
    var isAdmin: Bool
    var joinedAt: Date?
    
    init(userId: String, nickname: String? = nil, defaultAgency: String = "TTC", isPremium: Bool = false, isAdmin: Bool = false, joinedAt: Date? = nil) {
        self.userId = userId
        self.nickname = nickname
        self.defaultAgency = defaultAgency
        self.isPremium = isPremium
        self.isAdmin = isAdmin
        self.joinedAt = joinedAt
    }
}
