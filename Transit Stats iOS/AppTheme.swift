import SwiftUI

enum AppTheme: String, CaseIterable {
    case auto   = "auto"
    case blue   = "blue"
    case indigo = "indigo"
    case purple = "purple"
    case teal   = "teal"
    case green  = "green"
    case red    = "red"

    var label: String {
        switch self {
        case .auto:   return "Auto"
        case .blue:   return "Blue"
        case .indigo: return "Indigo"
        case .purple: return "Purple"
        case .teal:   return "Teal"
        case .green:  return "Green"
        case .red:    return "Red"
        }
    }

    // Static colour for the swatch; Auto shows a gradient placeholder
    var swatchColor: Color {
        switch self {
        case .auto:   return Color(hex: "0066FF")
        case .blue:   return Color(hex: "0066FF")
        case .indigo: return .indigo
        case .purple: return .purple
        case .teal:   return .teal
        case .green:  return Color(hex: "00C853")
        case .red:    return Color(hex: "FF3B30")
        }
    }

    // Resolved colour given the user's top agency
    func resolved(topAgency: String?) -> Color {
        if self == .auto {
            return AppTheme.agencyColor(for: topAgency)
        }
        return swatchColor
    }

    static func agencyColor(for agency: String?) -> Color {
        switch (agency ?? "").uppercased() {
        case "TTC":       return Color(hex: "ED1C24")   // TTC red
        case "GO", "GO TRANSIT": return Color(hex: "00853F") // GO green
        case "MiWay", "MIWAY":   return Color(hex: "E4002B")
        case "YRT", "VIVA":      return Color(hex: "0072BC")
        case "BRAMPTON", "BT":   return Color(hex: "E4002B")
        case "HSR":              return Color(hex: "FFD100")
        case "OC TRANSPO", "OC": return Color(hex: "E4002B")
        case "STM":              return Color(hex: "009EE0")
        case "Calgary TRANSIT":  return Color(hex: "CC0000")
        default:                 return Color(hex: "0066FF")
        }
    }
}
