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
}
