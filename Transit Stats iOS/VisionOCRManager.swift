import Foundation
import UIKit
import Vision

class VisionOCRManager {
    static let shared = VisionOCRManager()
    
    func processImage(_ image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                    completion([])
                    return
                }
                let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
                completion(recognizedStrings)
            }
            request.recognitionLevel = .accurate

            do {
                try requestHandler.perform([request])
            } catch {
                completion([])
            }
        }
    }
    
    /// Extracts likely route numbers from a list of recognized strings.
    func extractRoutes(from strings: [String]) -> [String] {
        let routePattern = #"^\b\d{1,4}[A-Za-z]?\b$"#
        let regex = try? NSRegularExpression(pattern: routePattern)
        
        return strings.filter { string in
            let range = NSRange(location: 0, length: string.utf16.count)
            return regex?.firstMatch(in: string, options: [], range: range) != nil
        }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .reduce(into: [String]()) { unique, route in
            if !unique.contains(route) { unique.append(route) }
        }
    }
    
    /// Extracts likely stop names from a list of recognized strings.
    func extractStopNames(from strings: [String]) -> [String] {
        // Look for strings that look like transit stops:
        // - All caps
        // - Contains keywords like ST, AV, RD, STATION, COMPLEX
        // - Often contains a slash or ampersand
        let keywords = ["ST", "AV", "RD", "STATION", "STN", "WAY", "PL", "DR", "BLVD"]
        
        return strings.filter { string in
            let upper = string.uppercased()
            let hasKeyword = keywords.contains { upper.contains($0) }
            let hasSeparator = upper.contains("/") || upper.contains("&")
            let isMostlyAlpha = upper.rangeOfCharacter(from: CharacterSet.letters) != nil
            
            return (hasKeyword || hasSeparator) && isMostlyAlpha && string.count > 3
        }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
