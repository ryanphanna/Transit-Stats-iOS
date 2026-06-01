# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
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
