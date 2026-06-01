# Transit Stats iOS Roadmap

This roadmap outlines the planned features and platform-specific goals for the Transit Stats iOS companion application.

---

## 🔥 Priority

*   **Offline-First Trip Logging**:
    *   Trips are created and stored in SwiftData immediately on device — no network call needed to start a trip.
    *   The iOS app bypasses the HTTP API for trip creation entirely and writes the completed trip record directly to Firestore via the SDK on trip end. The HTTP API remains solely for the SMS bot.
    *   Direction and other optional fields can be updated on the active trip card during the journey; all data is held locally until the trip is ended.
    *   On trip end, a single Firestore write commits the complete record. If offline, the record is marked `isSynced = false` and flushed automatically when connectivity returns via `NWPathMonitor`.

*   **Incremental Sync**:
    *   On first launch, perform a full Firestore sync and store a `lastSyncedAt` timestamp in `UserDefaults`.
    *   On subsequent launches, query only documents updated since `lastSyncedAt` — eliminating redundant re-downloads of unchanged trip history.
    *   The UI renders instantly from the local SwiftData store; Firestore changes arrive as a lightweight background delta.

---

## 📋 Backlog

*   **Logger UI Enhancements**:
    *   Auto-suggest stop names in the boarding flow based on the user's trip history.
    *   Surface direction options intelligently on the active trip card rather than asking upfront.

*   **WidgetKit & Lock Screen Shortcuts**:
    *   Small/Medium home screen widgets to start a new trip with a single tap — pre-filled with a frequent route if one is detected.
    *   Lock Screen Live Activities showing the active trip in real time — current route, direction, and elapsed time — on the lock screen and Dynamic Island.

*   **watchOS Companion**:
    *   Fully standalone watch app with local SwiftData sync so trips can be logged and ended directly from the wrist.
    *   Haptic confirmation when a trip is successfully started.

*   **Siri & App Shortcuts**:
    *   Voice-activate trip logging via App Intents (e.g., *"Hey Siri, start my commute"*).
    *   Expose start/end trip actions to the Shortcuts app for custom automations (e.g., auto-start on leaving a home geofence).

*   **On-Device Intelligence (Core ML & Core Motion)**:
    *   *Motion-Based Trip Detection*: Use `CMMotionActivityManager` to passively detect when the user transitions into a vehicle and surface a prompt to start a trip — no need to open the app while waiting at the stop.
    *   *Smart Shortcut Ranking*: A lightweight on-device Core ML classifier trained on personal trip history ranks shortcuts by time of day and day of week, so the right route appears at the right time.
    *   *Trip Anomaly Detection*: Compare active trip duration against historical averages for the same route and prompt to end or discard if it runs unusually long — catching forgotten trips before they skew stats.

*   **"Rocket" Research Instrument (Admin Only)**:
    *   Restricted to admin users; provides high-fidelity telemetry for transit research.
    *   *Background GPS breadcrumbing*: Record the entire journey path (high-frequency GPS) for the duration of the session.
    *   *Real-time event logging*: Dedicated interface to capture micro-events like Door state (dwell time), Signal state (delays), and Motion state.
    *   *Direct Telemetry Sync*: Persist telemetry events directly to the specialized `rocket_trips` Firestore collection.
