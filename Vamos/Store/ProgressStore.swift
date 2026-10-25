import Foundation
import SwiftUI

// MARK: - Spaced repetition

struct SRSCard: Codable, Identifiable {
    var id: String { itemId }
    let itemId: String
    var ease: Double = 2.5
    /// Current interval in days.
    var interval: Double = 0
    var reps: Int = 0
    var lapses: Int = 0
    var due: Date
}

enum ReviewRating: Int, CaseIterable {
    case again, hard, good, easy

    var title: String {
        switch self {
        case .again: return "忘了"
        case .hard: return "模糊"
        case .good: return "记得"
        case .easy: return "简单"
        }
    }
}

enum SRS {
    /// SM-2 style scheduling, simplified.
    static func schedule(_ card: SRSCard, rating: ReviewRating, now: Date = Date()) -> SRSCard {
        var c = card
        switch rating {
        case .again:
            c.reps = 0
            c.lapses += 1
            c.ease = max(1.3, c.ease - 0.2)
            c.interval = 0
            c.due = now.addingTimeInterval(10 * 60)
            return c
        case .hard:
            c.ease = max(1.3, c.ease - 0.15)
            c.interval = max(1, c.interval * 1.2)
        case .good:
            if c.reps == 0 { c.interval = 1 }
            else if c.reps == 1 { c.interval = 3 }
            else { c.interval = max(c.interval + 1, c.interval * c.ease) }
        case .easy:
            if c.reps == 0 { c.interval = 3 }
            else { c.interval = max(c.interval + 2, c.interval * c.ease * 1.3) }
            c.ease += 0.15
        }
        c.reps += 1
        c.due = Calendar.current.startOfDay(for: now).addingTimeInterval(c.interval * 86_400)
        return c
    }

    static func label(for card: SRSCard, rating: ReviewRating) -> String {
        let next = schedule(card, rating: rating)
        if rating == .again { return "10 分钟" }
        return intervalText(next.interval)
    }

    static func intervalText(_ days: Double) -> String {
        if days < 1.5 { return "1 天" }
        if days < 30 { return "\(Int(days.rounded())) 天" }
        if days < 365 { return String(format: "%.1f 个月", days / 30) }
        return String(format: "%.1f 年", days / 365)
    }
}

// MARK: - Saved progress

struct LessonRecord: Codable {
    var bestAccuracy: Double
    var timesCompleted: Int
    var lastCompleted: Date
}

struct ProgressData: Codable {
    var lessons: [String: LessonRecord] = [:]
    var cards: [String: SRSCard] = [:]
    var xp: Int = 0
    /// "yyyy-MM-dd" → XP earned that day.
    var xpByDay: [String: Int] = [:]
    /// Words and sentences saved from the dictionary, reading, chat, etc.
    var customItems: [String: Item] = [:]
    /// Index of the level the placement test put the learner in (levels below it are open).
    var placementLevel: Int = 0
    /// Minutes of AI conversation, writing pieces checked, etc.
    var chatTurns: Int = 0
    var writingsChecked: Int = 0

    init() {}

    // Tolerant decoding so older save files keep working.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lessons = try c.decodeIfPresent([String: LessonRecord].self, forKey: .lessons) ?? [:]
        cards = try c.decodeIfPresent([String: SRSCard].self, forKey: .cards) ?? [:]
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        xpByDay = try c.decodeIfPresent([String: Int].self, forKey: .xpByDay) ?? [:]
        customItems = try c.decodeIfPresent([String: Item].self, forKey: .customItems) ?? [:]
        placementLevel = try c.decodeIfPresent(Int.self, forKey: .placementLevel) ?? 0
        chatTurns = try c.decodeIfPresent(Int.self, forKey: .chatTurns) ?? 0
        writingsChecked = try c.decodeIfPresent(Int.self, forKey: .writingsChecked) ?? 0
    }
}

final class ProgressStore: ObservableObject {
    @Published private(set) var data: ProgressData

    private let fileURL: URL
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("progress.json")
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(ProgressData.self, from: raw) {
            data = decoded
        } else {
            data = ProgressData()
        }
        ItemIndex.shared.register(Array(data.customItems.values))
    }

    private func save() {
        do {
            let raw = try JSONEncoder().encode(data)
            try raw.write(to: fileURL, options: .atomic)
        } catch {
            print("Save failed: \(error)")
        }
    }

    // MARK: Lessons

    func isCompleted(_ lessonId: String) -> Bool { data.lessons[lessonId] != nil }

    /// A level opens when the previous level is finished, or the placement test put you there.
    func isLevelUnlocked(_ levelIndex: Int, unlockAll: Bool) -> Bool {
        if unlockAll || levelIndex <= data.placementLevel { return true }
        let levels = CourseStore.shared.levels
        guard levelIndex > 0, levelIndex < levels.count else { return levelIndex == 0 }
        return levels[levelIndex - 1].lessons.allSatisfy { isCompleted($0.id) }
    }

    func isUnlocked(_ entry: LessonEntry, unlockAll: Bool) -> Bool {
        if unlockAll || isCompleted(entry.id) { return true }
        let store = CourseStore.shared
        let levelIndex = store.levelIndex(entry.levelId)
        guard isLevelUnlocked(levelIndex, unlockAll: false) else { return false }
        // Levels below the placement level are fully open.
        if levelIndex < data.placementLevel { return true }
        let lessons = store.levels[levelIndex].lessons
        guard let index = lessons.firstIndex(where: { $0.id == entry.id }) else { return false }
        return index == 0 || isCompleted(lessons[index - 1].id)
    }

    /// The first lesson not yet completed, in an unlocked level.
    var currentLesson: LessonEntry? {
        let store = CourseStore.shared
        let floor = data.placementLevel
        return store.lessonsInOrder.first {
            !isCompleted($0.id) && store.levelIndex($0.levelId) >= floor && isUnlocked($0, unlockAll: false)
        }
    }

    var currentLessonId: String? { currentLesson?.id }

    /// Best guess at the learner's level, used to pitch AI content.
    var learnerLevel: String {
        let store = CourseStore.shared
        if let current = currentLesson { return current.levelId }
        return store.levels.last?.id ?? "A1"
    }

    func setPlacement(_ levelIndex: Int) {
        data.placementLevel = max(0, levelIndex)
        save()
    }

    func completedCount(inLevel levelId: String) -> Int {
        CourseStore.shared.level(levelId)?.lessons.filter { isCompleted($0.id) }.count ?? 0
    }

    var completedCount: Int { data.lessons.count }

    /// Records a finished lesson. Returns XP earned.
    @discardableResult
    func completeLesson(_ lesson: Lesson, result: PracticeResult) -> Int {
        ItemIndex.shared.register(lesson.items)
        let now = Date()
        var record = data.lessons[lesson.id] ?? LessonRecord(bestAccuracy: 0, timesCompleted: 0, lastCompleted: now)
        let firstTime = record.timesCompleted == 0
        record.bestAccuracy = max(record.bestAccuracy, result.accuracy)
        record.timesCompleted += 1
        record.lastCompleted = now
        data.lessons[lesson.id] = record

        let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        for item in lesson.items where data.cards[item.id] == nil {
            data.cards[item.id] = SRSCard(itemId: item.id, due: tomorrow)
        }
        flagMistakes(result.missedItemIds, now: now)

        let gained = (firstTime ? 10 : 5) + result.firstTryCorrect
        addXPInternal(gained, now: now)
        save()
        return gained
    }

    // MARK: Review

    func dueCards(now: Date = Date()) -> [SRSCard] {
        data.cards.values
            .filter { $0.due <= now && CourseStore.shared.item($0.itemId) != nil }
            .sorted { $0.due < $1.due }
    }

    var dueCount: Int { dueCards().count }

    var learnedItems: [Item] {
        data.cards.keys.compactMap { CourseStore.shared.item($0) }
    }

    var masteredCount: Int { data.cards.values.filter { $0.interval >= 21 }.count }

    var troubleItems: [Item] {
        data.cards.values
            .filter { $0.lapses > 0 }
            .sorted { $0.lapses > $1.lapses }
            .prefix(8)
            .compactMap { CourseStore.shared.item($0.itemId) }
    }

    func card(for itemId: String) -> SRSCard? { data.cards[itemId] }

    // MARK: Saved words

    func isSaved(es: String) -> Bool {
        data.customItems.values.contains { $0.es.lowercased() == es.lowercased() }
            || data.cards.keys.contains { CourseStore.shared.item($0)?.es.lowercased() == es.lowercased() }
    }

    /// Adds a word or sentence from anywhere in the app to the review deck (due now).
    func saveItem(es: String, zh: String, note: String? = nil, pron: String? = nil) {
        let clean = es.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isSaved(es: clean) else { return }
        let item = Item(id: "custom-" + UUID().uuidString.prefix(8).lowercased(), es: clean, zh: zh,
                        note: note, pron: pron, tts: nil)
        data.customItems[item.id] = item
        data.cards[item.id] = SRSCard(itemId: item.id, due: Date())
        ItemIndex.shared.register([item])
        save()
    }

    var savedItems: [Item] {
        data.customItems.values.sorted { $0.es.localizedCaseInsensitiveCompare($1.es) == .orderedAscending }
    }

    func deleteSaved(_ id: String) {
        data.customItems[id] = nil
        data.cards[id] = nil
        save()
    }

    func addXP(_ amount: Int) {
        addXPInternal(amount, now: Date())
        save()
    }

    func countChatTurn() {
        data.chatTurns += 1
        addXPInternal(2, now: Date())
        save()
    }

    func countWriting() {
        data.writingsChecked += 1
        addXPInternal(15, now: Date())
        save()
    }

    func review(itemId: String, rating: ReviewRating) {
        guard let card = data.cards[itemId] else { return }
        data.cards[itemId] = SRS.schedule(card, rating: rating)
        if rating != .again { addXPInternal(1, now: Date()) }
        save()
    }

    /// Practice mistakes become due immediately so they show up in review.
    func recordPractice(_ result: PracticeResult) {
        let now = Date()
        flagMistakes(result.missedItemIds, now: now)
        addXPInternal(result.firstTryCorrect, now: now)
        save()
    }

    private func flagMistakes(_ ids: Set<String>, now: Date) {
        for id in ids {
            if var card = data.cards[id] {
                card.due = min(card.due, now)
                data.cards[id] = card
            } else if CourseStore.shared.item(id) != nil {
                data.cards[id] = SRSCard(itemId: id, due: now)
            }
        }
    }

    // MARK: XP & streak

    private func addXPInternal(_ amount: Int, now: Date) {
        guard amount > 0 else { return }
        data.xp += amount
        data.xpByDay[Self.dayKey(now), default: 0] += amount
    }

    static func dayKey(_ date: Date) -> String { dayFormatter.string(from: date) }

    var todayXP: Int { data.xpByDay[Self.dayKey(Date())] ?? 0 }

    var streak: Int {
        let cal = Calendar.current
        var day = Date()
        if data.xpByDay[Self.dayKey(day)] == nil {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day),
                  data.xpByDay[Self.dayKey(yesterday)] != nil else { return 0 }
            day = yesterday
        }
        var count = 0
        while data.xpByDay[Self.dayKey(day)] != nil {
            count += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// XP for the last 7 days, oldest first.
    var lastWeek: [(label: String, xp: Int)] {
        let cal = Calendar.current
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        return (0..<7).reversed().compactMap { (offset: Int) -> (label: String, xp: Int)? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let weekday = cal.component(.weekday, from: day) - 1
            let label = offset == 0 ? "今天" : names[weekday]
            return (label: label, xp: self.data.xpByDay[Self.dayKey(day)] ?? 0)
        }
    }

    func resetAll() {
        data = ProgressData()
        save()
    }
}
