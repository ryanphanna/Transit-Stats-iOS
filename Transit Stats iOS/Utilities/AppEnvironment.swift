import SwiftUI
import Combine

final class AppEnvironment: ObservableObject {
    @Published var accentKey: String = UserDefaults.standard.string(forKey: "appAccent") ?? "blue" {
        didSet { UserDefaults.standard.set(accentKey, forKey: "appAccent") }
    }
    @Published var homeAgency: String? = nil

    var accent: Color {
        AppTheme(rawValue: accentKey)?.resolved(topAgency: homeAgency) ?? .blue
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static let supportEmail = "hey@ryanisnota.pro"
    static let platformName = "iOS Native"
}
