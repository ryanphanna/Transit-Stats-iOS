# Transit Stats iOS Roadmap

This roadmap outlines the planned milestones, features, and platform-specific goals for the Transit Stats iOS companion application.

---

## 🗺 Active Milestone: MVP Release & Sync Stability

Focus: Solidifying the core logging UI, offline-first reliability, and real-time background sync.

*   [x] **SMS OTP Login Flow**: Passwordless phone number sign-in via backend OTP Custom Token.
*   [ ] **Sync Optimization**:
    *   Implement smart debounce/throttling for local SwiftData changes.
    *   Handle offline conflict resolution when database edits happen concurrently.
*   [ ] **Logger UI Enhancements**:
    *   Auto-suggest route/stop names based on user history or location.
    *   Quick-log widgets or home screen shortcuts for frequent trips.

---

## 📋 Future Milestones

### Milestone 1: WidgetKit & Lock Screen Shortcuts
*   **Quick-Access Widgets**: Small/Medium home screen widgets to log a new trip with a single tap.
*   **Lock Screen Live Activities**: Display active trip progress (e.g., duration elapsed, current route) directly on the lock screen.

### Milestone 2: watchOS Companion
*   **Apple Watch App**: Fully standalone watch app (with offline cache sync) to log transit stats directly from your wrist when your iPhone is away.

### Milestone 3: Siri & App Shortcuts
*   **Siri Shortcuts Integration**: Voice-activate trip logging (e.g., *"Siri, start logging my transit trip"*).
*   **App Intents**: Expose actions to Apple Shortcuts for custom automation chains.
