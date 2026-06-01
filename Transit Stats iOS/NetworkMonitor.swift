import Foundation
import Network
import SwiftData
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let connected = path.status == .satisfied
                if connected && !self!.isConnected {
                    // Transitioned from offline to online
                    print("Network restored. Triggering background sync.")
                    self?.isConnected = true
                    // We can't trigger sync here directly without a ModelContext
                } else {
                    self?.isConnected = connected
                }
            }
        }
        monitor.start(queue: queue)
    }
}
