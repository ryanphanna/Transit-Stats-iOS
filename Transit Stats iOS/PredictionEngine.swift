import Foundation
import SwiftData

/// On-device Prediction Engine ported from Transit Stats V3 (JS).
/// Uses weighted voting across historical trips to predict the next likely journey.
struct PredictionEngine {
    
    struct Config {
        static let timeSigmaHours: Double = 1.5
        static let decayHalfLifeDays: Double = 20.0
        static let sequenceBoost: Double = 1.5
    }
    
    struct Prediction {
        let route: String
        let direction: String
        let confidence: Double
        let reason: String
    }
    
    /// Predicts the likely next trip based on history and current context.
    static func predict(history: [TripRecord], stopName: String?, currentTime: Date = Date()) -> [Prediction] {
        guard !history.isEmpty else { return [] }
        
        let normalizedStop = stopName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Filter history to trips starting at this stop (if provided)
        let candidates = history.filter { trip in
            if let targetStop = normalizedStop {
                return trip.startStopName?.lowercased().contains(targetStop) ?? false ||
                       trip.startStopCode?.lowercased() == targetStop
            }
            return true
        }
        
        guard !candidates.isEmpty else { return [] }
        
        var votes: [String: Double] = [:]
        var details: [String: (route: String, direction: String)] = [:]
        
        for trip in candidates {
            let weight = calculateWeight(for: trip, relativeTo: currentTime)
            let key = "\(trip.route)|\(trip.direction)"
            
            votes[key, default: 0] += weight
            details[key] = (trip.route, trip.direction)
        }
        
        let totalWeight = votes.values.reduce(0, +)
        guard totalWeight > 0 else { return [] }
        
        // Sort and convert to Predictions
        return votes.map { key, weight in
            let detail = details[key]!
            let confidence = weight / totalWeight
            return Prediction(
                route: detail.route,
                direction: detail.direction,
                confidence: confidence,
                reason: "Based on \(Int(weight * 10)) matches in history"
            )
        }
        .sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Scoring Functions
    
    private static func calculateWeight(for trip: TripRecord, relativeTo now: Date) -> Double {
        let recency = recencyWeight(startTime: trip.startTime, now: now)
        let timeSim = timeSimilarity(timeA: trip.startTime, timeB: now)
        let daySim = daySimilarity(dayA: Calendar.current.component(.weekday, from: trip.startTime),
                                  dayB: Calendar.current.component(.weekday, from: now))
        
        return recency * timeSim * daySim
    }
    
    /// Exponential decay based on days passed.
    private static func recencyWeight(startTime: Date, now: Date) -> Double {
        let diff = now.timeIntervalSince(startTime)
        let days = diff / (24 * 3600)
        if days < 0 { return 0 } // Trip in the future?
        return pow(0.5, days / Config.decayHalfLifeDays)
    }
    
    /// Gaussian similarity for time of day (ignoring date).
    private static func timeSimilarity(timeA: Date, timeB: Date) -> Double {
        let cal = Calendar.current
        let minutesA = cal.component(.hour, from: timeA) * 60 + cal.component(.minute, from: timeA)
        let minutesB = cal.component(.hour, from: timeB) * 60 + cal.component(.minute, from: timeB)
        
        var diff = Double(abs(minutesA - minutesB))
        if diff > 720 { diff = 1440 - diff } // Handle wrap-around at midnight
        
        let diffHours = diff / 60.0
        let sigma = Config.timeSigmaHours
        return exp(-(diffHours * diffHours) / (2 * sigma * sigma))
    }
    
    /// Simple binary or proximity weight for day of week.
    private static func daySimilarity(dayA: Int, dayB: Int) -> Double {
        if dayA == dayB { return 1.0 }
        
        // Weekend vs Weekday check
        let isWeekendA = (dayA == 1 || dayA == 7)
        let isWeekendB = (dayB == 1 || dayB == 7)
        
        if isWeekendA == isWeekendB { return 0.5 } // Both weekdays or both weekends
        return 0.1 // Mixed
    }
}
