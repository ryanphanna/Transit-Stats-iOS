import SwiftUI
import FirebaseCore
import SwiftData

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize Firebase programmatically without GoogleService-Info.plist using Transit Stats config
        let options = FirebaseOptions(
            googleAppID: "1:756203797723:ios:2e5aab94a6de20cf06a0fe",
            gcmSenderID: "756203797723"
        )
        options.apiKey = Config.apiKey
        options.projectID = "transitstats-21ba4"
        options.storageBucket = "transitstats-21ba4.firebasestorage.app"
        
        FirebaseApp.configure(options: options)
        print("Firebase initialized programmatically for iOS app.")
        return true
    }
}

@main
struct Transit_Stats_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [TripRecord.self, Stop.self, UserProfile.self, Hub.self, PredictionAccuracy.self])
    }
}
