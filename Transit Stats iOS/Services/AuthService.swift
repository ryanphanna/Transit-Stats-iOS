import Foundation
import FirebaseAuth
import Combine

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    private let baseURL = URL(string: "https://us-central1-transitstats-21ba4.cloudfunctions.net/api")!
    
    @Published var currentUser: User? = Auth.auth().currentUser
    @Published var isAuthenticating = false
    
    private init() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.currentUser = user
        }
    }
    
    func requestOtp(phoneNumber: String) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "action": "request_otp",
            "phoneNumber": phoneNumber
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }
        
        if httpResponse.statusCode != 200 {
            if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorObj["error"] as? String {
                throw NSError(domain: "AuthService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            throw NSError(domain: "AuthService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to send code (\(httpResponse.statusCode))"])
        }
    }
    
    func verifyOtp(phoneNumber: String, code: String) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "action": "verify_otp",
            "phoneNumber": phoneNumber,
            "code": code
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }
        
        if httpResponse.statusCode != 200 {
            if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorObj["error"] as? String {
                throw NSError(domain: "AuthService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            throw NSError(domain: "AuthService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Verification failed (\(httpResponse.statusCode))"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else {
            throw NSError(domain: "AuthService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Response missing token"])
        }
        
        try await Auth.auth().signIn(withCustomToken: token)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func getIdToken() async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "AuthService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        return try await currentUser.getIDToken()
    }
}
