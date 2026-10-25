import Foundation

/// UserDefaults keys used with @AppStorage.
enum Prefs {
    static let speechRate = "speechRate"
    static let defaultSpeechRate = 0.42
    static let autoPlay = "autoPlay"
    static let dailyGoal = "dailyGoal"
    static let unlockAll = "unlockAll"
    static let reviewDirection = "reviewDirection"
    static let reminderOn = "reminderOn"
    static let reminderHour = "reminderHour"
    static let reminderMinute = "reminderMinute"
    static let learnerBackground = "learnerBackground"
    static let speakingDrills = "speakingDrills"
    static let chatAutoSpeak = "chatAutoSpeak"
    static let chatCorrections = "chatCorrections"
    static let selectedLevel = "selectedLevel"
}

enum ReviewDirection: Int, CaseIterable, Identifiable {
    case esToZh = 0, zhToEs = 1, mixed = 2
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .esToZh: return "西 → 中"
        case .zhToEs: return "中 → 西"
        case .mixed: return "混合"
        }
    }
}
