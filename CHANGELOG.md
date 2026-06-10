# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed
- **Architectural Overhaul (MVVM)**: Implemented Model-View-ViewModel architecture across all core views (`HomeView`, `AddTripView`, `StatsView`). Extracted massive amounts of business logic, state management, and analytical calculations into dedicated ViewModels, reducing view file sizes by ~30-50%.
- **Decomposed TransitStatsAPI**: Broke down the "God Class" `TransitStatsAPI` into specialized, decoupled services:
    - `AuthService`: Dedicated to OTP flows and Firebase session management.
    - `TripService`: Specialized Firestore CRUD operations and backend command processing.
    - `SyncManager`: Isolated real-time synchronization and SwiftData reconciliation logic.
- **Liquid Glass Navigation**: Replaced the system tab bar with a custom "Liquid Glass" style floating capsule bar. The "GO" button is now integrated directly into the bar, positioned horizontally between the Explore and Stats tabs for a sleeker, more unified look.
- **Project Directory Restructuring**: Reorganized the entire codebase into a logical folder hierarchy (`Models`, `Views`, `ViewModels`, `Services`, `Utilities`, `Resources`) for improved maintainability and discovery.
- **View Componentization**: Decomposed massive view files (`HomeView`, `StatsView`) into modular, reusable components. Extracted ~10 subviews into dedicated files under `Views/Components/`, reducing main view file sizes by ~80% and improving UI testing isolation.

### Fixed
- **AddTripView: GPS start location missed on slow fix**: `locateUser()` previously waited a blind 1.5s before proceeding. Now polls every 250ms for an accurate fix, up to 5 seconds, so trips started immediately after tapping Locate still capture a valid start coordinate.

### Added
- **Linked trips / Journey view**: `TripRecord` now stores `journeyId` (synced from Firestore). In the Trips list, trips sharing a journey are connected with a vertical line and a link badge. In TripDetailView, a Journey section shows the other legs with route, stop, and duration — plus an Unlink button that clears the `journeyId` locally and in Firestore.

### Changed
- **HomeView: Ready state panel**: Replaced the minimal "Ready to go?" + single button layout with a richer panel showing a quick stats strip (total trips / this week / last trip), the Start New Trip button, quick-start shortcuts for frequent routes, and a compact recent trips list.
- **TripRow: Stop name truncation**: Changed FROM → TO from a single truncated HStack to a vertical stack (origin on line 1, destination indented below with a down arrow), so full stop names are readable without ellipsis.
- **TripDetailView: Source/sync moved to footer**: Removed SOURCE and SYNC from the prominent stats strip (which now shows DATE and DURATION only). Source and sync status now appear as small-print text at the bottom of the info card ("Logged via App · Synced").

### Fixed
- **AddTripView: Double drag indicator**: Suppressed the system sheet drag indicator (`.presentationDragIndicator(.hidden)`) since AddTripView renders its own capsule handle, removing the duplicate lines.
- **AddTripView: No way to dismiss**: Added an ✕ button to the top-right of the sheet header so users can cancel without having to swipe down.
- **StatsView: Streak calculation**: Streak now counts days with any logged trip (was incorrectly filtering to completed trips only, causing the streak to show 0 for users with many trips that don't have an end time).
- **StatsView: Rank system removed**: Removed the rank badge and rank computed property entirely from the passport card. The identity row now shows only the rider's nickname and join date.
- **StatsView: Redundant Identification card**: Removed the separate "Identification" card. Rider nickname, rank badge, and join date are now merged directly into the Passport card.
- **StatsView: "All Transit Stats" button**: Removed the redundant button — scrolling achieves the same result.
- **AddTripView: Theming**: AddTripView now uses the app-wide accent colour (via `AppEnvironment`) instead of hardcoded blue, keeping it consistent across all colour themes. Background changed from `Color.clear` to `Color.appBackground` so the sheet matches the rest of the app.
- **SettingsView: Name editing**: Tapping "Edit" now auto-focuses the name text field so the keyboard appears immediately.
- **SettingsView: Home Agency placement**: Moved "Home Agency" from the App Info section into the Theme section, where it belongs contextually (it drives the Auto accent mode).
- **HomeView: Default panel height**: Increased default snap height from 300 → 380 pts (roughly half screen) for a more useful initial view.
- **HomeView: In Transit badge**: Changed the "In Transit" live-status badge to use a fixed green colour instead of the accent, so it reads as a live/active indicator regardless of the user's chosen theme.

### Fixed
- **Home panel content layout**: Panel content was being pushed to the bottom because `Color.clear` with `minHeight` expands to fill all available space. Fixed by locking the drag handle to an exact 48pt height.
- **Locate button broken**: Button did nothing when GPS hadn't resolved yet. Restored fallback to MapKit's native user-location tracking when `lastLocation` is nil.
- **Home panel drag**: Drag handle is now a 48px tall hit target (was ~24px), making it reliably swipeable to expand/collapse the panel.
- **Map camera on load**: Map no longer zooms out to fit all historical trip markers across the GTA. Now centers on the user's GPS location at a neighbourhood-level zoom; falls back to top-10 most-visited hubs only if location is unavailable.
- **Map camera jumping**: Removed the `onChange(of: mapMarkers.count)` handler that was re-fitting the map camera every time a marker loaded, causing the map to snap around unexpectedly.
- **Locate button**: No longer falls back to a city-wide "fit all markers" view when GPS hasn't resolved yet. Button only zooms if a location is available.
- **AddTripView double drag indicator**: Removed system sheet drag indicator (`.presentationDragIndicator(.visible)`) since AddTripView renders its own capsule handle.
