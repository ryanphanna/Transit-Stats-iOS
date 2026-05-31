import Foundation
import FirebaseAuth
import SwiftUI
import Combine

/// Singleton manager tracking the Firebase Auth state.
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: User? = nil
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true
    
    private var authListener: AuthStateDidChangeListenerHandle?
    
    private init() {
        self.authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.isCheckingAuth = false
            }
        }
    }
    
    deinit {
        if let authListener = authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Failed to sign out: \(error.localizedDescription)")
        }
    }
}
