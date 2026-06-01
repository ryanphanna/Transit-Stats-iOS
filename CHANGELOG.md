# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **On-Device OCR "Scan to Start"**: Integrated the Vision framework to allow users to scan bus poles, stop signs, or vehicle numbers via the camera. The app automatically extracts route numbers and stop names, pre-filling the logger for a high-speed, zero-typing entry experience.
- **Strictly Normalized Hub Model**: Refactored the app to follow a strictly normalized data architecture. Trips now link exclusively to Stops (via names/codes), and Hub resolution is performed dynamically via the local Stops library. Removed denormalized `startHubId` and `endHubId` fields from the trip model.
- **Hub-Based Stop Suggestions**: Refactored the `AddTripView` logger to group individual boarding platforms into consolidated "Hubs." Users now see a single, verified chip for an intersection (e.g., Spadina / Dundas) instead of multiple scattered suggestions, significantly reducing UI clutter.
- **Database-Driven Hub Model**: Updated the iOS `Stop` model and sync engine to support the new Firestore `hubId` and `verified` flags, enabling high-confidence matching and verified stop seals.
- **GPS Data Quality Filtering**: Updated the location capture engine to automatically discard coordinates with poor horizontal accuracy (> 65m). This prevents "noisy" data from subways or tunnels from skewing your trip history and ensures the normalized stops library remains high-quality.
- **Background GPS Validation**: Implemented silent GPS quality filtering for the HomeView map visualization.
- **Optimized Data Sync Strategy**: Implemented "Initial Hydration" and incremental syncing. Power users now see their most recent 50 trips instantly, while the rest of their history backfills in the background. Subsequent launches only sync delta changes, significantly reducing battery and data usage.
- **Intelligent Direction Suggestions**: Enhanced `AddTripView` to automatically predict and suggest journey directions based on historical patterns, further reducing manual input.
- **Polished Map Hubs**: Added visual refinements to the HomeView map, including scaled hub markers (based on frequency), pulsing active trip animations, and smart auto-framing of the camera view.
- **Dynamic Timezone Support**: Updated `TripRecord` to automatically detect and use the device's current timezone, ensuring accurate local-time logging and backend analytics regardless of location.
- **Nearby Stop Suggestions**: Integrated GPS-based stop lookup in `AddTripView`, surfacing the 5 nearest stops from the normalized library for one-tap selection.
- **Stop Library Sync**: Added automatic synchronization of the normalized Firestore `stops` collection to local SwiftData storage.
- **Boarding Hub Map Clustering**: Refactored the HomeView map to show consolidated "Hubs" for frequent boarding stops. Each hub displays a trip count badge, providing a cleaner and more data-driven visualization of transit usage.
- **Interactive Trip Map**: Enhanced the HomeView map to display markers for recent trip start and end points, providing immediate visual feedback for collected GPS data.
- **On-Device Prediction Engine**: Ported the heuristic weighted-voting engine to Swift for offline route suggestions and intelligent shortcut ranking.
- **GPS Location Tracking**: Integrated `CoreLocation` to automatically capture latitude and longitude for trip start and end points.
- **Offline-First Trip Logging**: Refactored `AddTripView` and `HomeView` to persist trips locally to SwiftData immediately, removing network dependency for starting/ending trips.
- **Direct Firestore Sync**: Implemented direct-to-Firestore write capability in `TransitStatsAPI.swift` for completed trips, bypassing legacy HTTP API for app-initiated actions.
- **Network Resilience Engine**: Added `NetworkMonitor` to detect connectivity changes and `SyncManager.syncPendingTrips` to automatically flush offline data when online.
- **Local Shortcuts**: Refactored HomeView shortcuts to use local-first architecture for instant logging in low-connectivity areas.
- **iOS Companion App**: Created the SwiftUI core app scaffold with SwiftData persistence for offline logging and local trip storage.
- **Real-Time Sync Engine** (`TransitStatsAPI.swift`): Integrates Firestore snapshots listener to synchronize database trip documents with the local SwiftData store automatically.
- **Dashboard, Logger, and Analytics Views** (`HomeView.swift`, `AddTripView.swift`, `StatsView.swift`): Implemented premium SwiftUI interfaces for active trip status logging, structured manual entry form, and Swift Charts metrics visualization.
- **Firebase iOS SDK**: Integrated `FirebaseCore`, `FirebaseAuth`, and `FirebaseFirestore` via Swift Package Manager to support user authentication and real-time database sync.
