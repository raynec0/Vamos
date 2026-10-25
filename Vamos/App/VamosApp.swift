import SwiftUI

@main
struct VamosApp: App {
    @StateObject private var progress = ProgressStore()

    init() {
        // Load cached AI lessons early so their words can appear in review.
        _ = LessonRepository.shared
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Prefs.reminderOn) {
            let hour = defaults.object(forKey: Prefs.reminderHour) as? Int ?? 20
            let minute = defaults.object(forKey: Prefs.reminderMinute) as? Int ?? 0
            Reminder.schedule(hour: hour, minute: minute) { _ in }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(progress)
                .tint(.vRojo)
        }
    }
}
