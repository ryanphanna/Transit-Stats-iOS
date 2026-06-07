# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Final Design Polish & Branding**: Standardized the entire app's color palette (Deep Navy, Brand Blue) and updated the `LoginView` to match the premium dark theme.
- **Empty State Views**: Implemented a "No Trips Yet" view in the history tab to provide a better experience for new users.
- **Responsive Home Panel**: Refactored the bottom panel on the Home screen to use a dedicated drag zone at the top. This eliminates gesture conflicts with the internal scroll view, making it much easier to swipe the panel up and down.
- **Medium-Detent Sheets**: Updated the "Add Trip" and "Settings" screens to open as non-full-screen sheets (medium detent) by default. This allows for a much faster "quick log" experience without losing context of the map.
- **Elegant Map Markers**: Redesigned map markers to be more refined and integrated with the map. Active trips now feature a glowing, pulsing icon, while transit hubs are represented by high-contrast 'dots' with translucent borders. This replaces the basic numbered circles with a more professional, Apple Maps-inspired aesthetic.
- **Standardized Panel Backgrounds**: Synchronized the background styling of the Home screen 'Ready' panel and the 'Add Trip' sheet. Both now use a consistent `ultraThinMaterial` for a cohesive, premium translucent look across the app.
- **One-Tap 'Locate' in Logger**: Added a dedicated Locate button to the boarding logger (`AddTripView`). Tapping it instantly scans for nearby transit stops and surfaces them as one-tap chips, eliminating the need to type your current location.
- **Dynamic Agency Stats**: The Agencies section on the Stats page now respects the year filter and is limited to your Top 5 most-used agencies, providing a cleaner and more relevant breakdown of your transit habits.
- **Stats Year Picker Relocation**: Moved the year filter ("All Time", "2026", etc.) from the main scroll view to a clean `Menu` in the top-right of the navigation bar. This declutters the Stats page and provides a more native iOS filtering experience.
- **Trip Detail View Redesign**: Overhauled the trip detail sheet with a premium, high-fidelity aesthetic. Includes a new hero section with a stylized route badge, a refined journey timeline with better iconography, a 3-column stats grid, and improved details cards.
- **Centralized App Constants**: Moved app version, support email, and platform name to `AppEnvironment` for single-point management.
- **Theme Color System**: Created `Color+Theme.swift` to centralize brand colors (backgrounds, gradients) and eliminate hardcoded hex strings.

### Fixed
- **Home Panel Clipping**: Fixed an issue where the "COMPLETE JOURNEY" and "START NEW TRIP" buttons were partially obscured by the system tab bar. Increased the panel's bottom padding and adjusted snap heights to ensure all controls are fully visible and accessible.
- **Settings Hierarchy**: Refactored the Account section to prioritize the user's name/nickname, with the masked Account ID moved to a secondary, smaller position. Relocated "Home Agency" to a new dedicated Preferences section to improve information hierarchy.
- **Rank Terminology**: Updated the top-tier user rank from "System Master" to "System Elite" for more inclusive and professional terminology.
- **Home Panel Layout**: Fixed an issue where the "Start New Trip" and "Complete Journey" buttons were partially cut off by the system tab bar. Increased bottom padding for the Home screen panel to ensure full visibility.
- **UI Clarification**: Replaced the confusing "Standby" badge on the Home screen with a clearer "Ready" indicator and an active green status dot.

### Refactored
- **Modular View Architecture**: Split the monolithic `ContentView.swift` (1000+ lines) into focused, maintainable files: `LoginView`, `MainTabView`, `TripsHistoryView`, `TripRow`, `TripDetailView`, and `SettingsView`.
- **Dynamic Versioning**: UI now automatically pulls the marketing version from the app Bundle.

## [1.2.0] - 2026-06-07

### Added
- **Trip Detail View**: Tapping any trip in history opens a full detail sheet — large route badge, boarded/alighted timeline with stop names and times, duration/date/time stat pills, source, sync status, vehicle, and notes.
- **Profile Picture**: Users can set a profile photo via the photo library. Photo is stored locally on-device (no upload). Appears on the transit card (tap to change) and in the Settings account row.
- **Activity Heatmap**: Stats tab now shows a GitHub-style scrollable year heatmap. Each square is one day; colour intensity scales from 1 trip (faint) to 10+ trips (full accent). Computed on-device from local trip history — no network call.
- **Home Agency on Transit Card**: Stats card now shows your most-used agency as a badge in the top-right corner of the transit card.
- **Contact Us**: Settings now includes a Support section with a Contact Us link that opens Mail pre-addressed to hey@ryanisnota.pro with version number and short account ID in the subject line.

### Fixed
- **Start Trip button**: Tapping "Start New Trip" now correctly opens the trip logger. Previously the button was inside a sheet presenting another sheet, which iOS silently ignores.
- **Settings button**: Same root cause as above — now works correctly.
- **Tab bar hidden by panel**: Home screen panel is now a ZStack overlay (like Flighty) instead of a system sheet, so the tab bar stays fully visible at all times.
- **Compass behind status bar**: Compass is now positioned above the locate button in the bottom-right corner instead of the top-right where it overlapped the battery indicator.
- **Locate button zoom**: Tapping locate now zooms to street level (~400m radius) instead of city-wide.
- **App display name**: App now shows as "Transit Stats" on the home screen instead of "Transit Stats iOS".
- **Xcode warnings**: Eliminated `?? NSNull()` nil-coalescing warnings in `TransitStatsAPI.swift` by routing optional Firestore fields through a typed `nullable<T>` helper.

### Refactored
- **AppEnvironment**: Accent colour and home agency are now managed in a single `AppEnvironment` object injected at the root, eliminating duplicated `@AppStorage`/`topAgency`/`accent` declarations across five views.

### Fixed
- **Ghost Active Trip**: Active trip query now filters to `isSynced == false` only, preventing historical open SMS trips synced from Firestore from appearing as "In Transit" on the home screen. Discarding a trip no longer surfaces the next open trip from history.

### Changed
- **Trip Filters**: Trips history now has four filter rows — date range (All time / This week / This month / This year), source (All / App / SMS), and agency chips (one per agency in your history). All filters combine.
- **Onboarding Flow**: Login screen is now a two-stage flow — a full landing screen showing app features ("Get Started" button) slides into the phone number entry form with a spring transition. Back button returns to landing.
- **SMS Resend Cooldown**: After requesting a code, "Resend Code" is disabled for 60 seconds with a live countdown to prevent SMS spam.
- **Streak Tracking**: Stats screen now shows current commute streak and all-time best streak, calculated from consecutive days with completed trips.
- **Map Stop Fallback**: Home map now shows markers for trips that have no GPS data by looking up stop coordinates from the local stops library. SMS-logged trips with known stop names/codes will now appear on the map.
- **App Theme**: Added colour theme picker to Settings. Choose Blue, Indigo, Purple, Teal, Green, Red, or Auto (derives colour from your most-used transit agency). Accent colour propagates to badges, buttons, charts, and map markers across the whole app.
- **Draggable Home Panel**: Bottom panel is now a proper draggable sheet with three snap heights (compact, default, expanded) and spring snap-back animation.
- **Map Controls**: Added locate me and compass buttons to the map via native MapKit controls.
- **Removed Shortcuts Section**: Removed the Recent Shortcuts panel from the home screen.
- **Blue Accent**: Replaced all orange accent colours with blue throughout HomeView and AddTripView.
- **Trip History**: SMS-sourced trips with no stop name now display "Via SMS" instead of "Unknown origin" in trip history.
- **Panel Layout**: Removed nested card background from active trip and ready state cards — content now sits directly on the frosted glass panel.

## [1.1.0] - 2026-06-05

### Added
- **Stop Auto-Suggestions**: Implemented real-time stop suggestions in the boarding logger (`AddTripView`). When typing, suggestions are pulled from trip history (ranked by recency) and the local stop library (ranked by verified status), displayed in a dropdown-style vertical stack.

### Changed
- **Inline Directions**: Relocated direction prediction chips from the advanced details block to display inline directly below route input suggestions when a route is selected or typed.
- **Simplified Advanced Options**: Renamed the advanced options panel to "Add Agency" and removed the direction selector, keeping only the agency selector.


## [1.0.0] - 2026-06-03

### Changed
- **Premium UI Redesign**: Overhauled the entire app interface to achieve a cohesive, high-end "in-between" aesthetic (blending Transit App's bold clarity with Flighty's elegance).
- **Unified Visual Identity**: Standardized the deep navy background across all tabs and replaced default iOS lists with custom, card-based ScrollViews for a modern look.
- **Streamlined Add Trip Flow**: Redesigned the boarding step to focus on route entry and prediction chips, hiding secondary agency/direction selectors behind an advanced toggle to reduce form overload.
- **Polished Boarding Pass Aesthetic**: Refined the Home screen's active trip card with better font weights and a cleaner Origin-to-Destination timeline.
- **Improved Sheet Navigation**: Added explicit "Done" buttons to the Settings and Profile sheets for clearer dismissal.
- **Enhanced Privacy Display**: Replaced raw, confusing user IDs in Settings with masked "Account ID" strings.
- **Consistent Terminology**: Renamed "Analytics" to "Stats" throughout the app for consistent branding.

### Added
- **High-Fidelity Path Tracking (Admin Only)**: Implemented background GPS 'breadcrumb' tracking for active trips. When enabled via the new "Lab Features" setting, the app records a continuous path of coordinates and speed data. This enables high-precision distance and speed analytics while preserving battery for regular users via a passive-only default mode.
- **Full Offline Mirroring**: Implemented comprehensive offline caching for user profiles, station hubs, and prediction accuracy stats. The app now persists your preferred agency, canonical station names, and AI performance metrics locally, ensuring a fully personalized experience even without a network connection.
- **Transit Card Profile**: Implemented a premium "Transit Card" feature, inspired by Flighty's Passport. The profile now features a holographic digital card summarizing the user's transit career, including unique stats, top route badges, and dynamic rank titles (e.g., "System Master").
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
