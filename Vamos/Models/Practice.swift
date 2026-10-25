import Foundation

/// A multiple-choice question as shown on screen.
struct ChoiceQ {
    var instruction: String
    var prompt: String
    var promptSpanish: Bool
    var sub: String? = nil
    /// Hide the prompt text and show a big play button instead.
    var audioOnly: Bool = false
    /// What to say when the prompt's speaker is tapped (or auto-played).
    var speak: String? = nil
    var options: [String]
    var optionsSpanish: Bool
    var answer: Int
    var explain: String? = nil
    /// Shown (and spoken) after checking, e.g. the completed sentence.
    var reveal: String? = nil
}

struct PracticeQuestion: Identifiable {
    enum Kind {
        case choice(ChoiceQ)
        case build(BuildExercise)
        case type(TypeExercise)
        case match([Item])
        case speak(Item)
    }

    let id = UUID()
    let kind: Kind
    /// Vocabulary items this question tests (used to flag mistakes for review).
    let itemIds: [String]
    var isRetry: Bool = false

    func retry() -> PracticeQuestion {
        PracticeQuestion(kind: kind, itemIds: itemIds, isRetry: true)
    }

    /// Matching and speaking rounds are never repeated.
    var repeatsWhenWrong: Bool {
        switch kind {
        case .match, .speak: return false
        default: return true
        }
    }
}

struct PracticeResult {
    var total: Int
    var firstTryCorrect: Int
    var missedItemIds: Set<String>

    var accuracy: Double {
        total == 0 ? 1 : Double(firstTryCorrect) / Double(total)
    }
}

enum PracticeBuilder {

    private static var speakingEnabled: Bool {
        UserDefaults.standard.object(forKey: Prefs.speakingDrills) as? Bool ?? true
    }

    /// Questions for one lesson: auto-generated drills + the lesson's own exercises.
    static func questions(for lesson: Lesson, levelId: String) -> [PracticeQuestion] {
        let unitItems = CourseStore.shared.unitItems(for: lesson.id)
        let pool = unitItems.isEmpty ? lesson.items : unitItems
        let advanced = CourseStore.shared.levelIndex(levelId) >= 1
        var result: [PracticeQuestion] = []

        let drillItems = Array(lesson.items.shuffled().prefix(advanced ? 8 : 10))
        for (index, item) in drillItems.enumerated() {
            switch index % 3 {
            case 0: result.append(esToZh(item, primary: lesson.items, fallback: pool))
            case 1: result.append(zhToEs(item, primary: lesson.items, fallback: pool))
            default: result.append(listen(item, primary: lesson.items, fallback: pool))
            }
        }

        // Dictation for sentence-length items (from A2 up, or longer A1 phrases).
        let sentences = lesson.items.filter { !$0.isPair && $0.wordCount >= (advanced ? 3 : 4) }.shuffled()
        for item in sentences.prefix(advanced ? 2 : 1) {
            result.append(dictation(item))
        }

        for exercise in lesson.exercises {
            result.append(convert(exercise))
        }

        result.shuffle()

        if lesson.items.count >= 4 {
            let pairs = Array(lesson.items.shuffled().prefix(5))
            let q = PracticeQuestion(kind: .match(pairs), itemIds: pairs.map(\.id))
            result.insert(q, at: min(result.count, max(2, result.count / 2)))
        }

        // Finish with speaking practice.
        if speakingEnabled {
            let speakable = lesson.items.filter { !$0.isPair && $0.wordCount >= 2 }.shuffled()
            for item in speakable.prefix(2) {
                result.append(PracticeQuestion(kind: .speak(item), itemIds: [item.id]))
            }
        }
        return result
    }

    /// Mixed drill over items the learner has already met.
    static func freePractice(from items: [Item], count: Int = 12) -> [PracticeQuestion] {
        guard items.count >= 4 else { return [] }
        let picked = Array(items.shuffled().prefix(count))
        var result: [PracticeQuestion] = []
        for (index, item) in picked.enumerated() {
            switch index % 4 {
            case 0: result.append(esToZh(item, primary: items, fallback: items))
            case 1: result.append(zhToEs(item, primary: items, fallback: items))
            case 2: result.append(listen(item, primary: items, fallback: items))
            default:
                result.append(item.wordCount >= 3 && !item.isPair ? dictation(item)
                              : esToZh(item, primary: items, fallback: items))
            }
        }
        let pairs = Array(items.shuffled().prefix(5))
        result.insert(PracticeQuestion(kind: .match(pairs), itemIds: pairs.map(\.id)),
                      at: min(result.count, 4))
        return result
    }

    // MARK: Generators

    static func esToZh(_ item: Item, primary: [Item], fallback: [Item]) -> PracticeQuestion {
        let (options, answer) = makeOptions(correct: item.zh,
                                            pool: distractors(for: item, primary: primary, fallback: fallback).map(\.zh))
        let q = ChoiceQ(instruction: "选出正确的意思",
                        prompt: item.es, promptSpanish: true,
                        speak: item.speakText,
                        options: options, optionsSpanish: false, answer: answer)
        return PracticeQuestion(kind: .choice(q), itemIds: [item.id])
    }

    static func zhToEs(_ item: Item, primary: [Item], fallback: [Item]) -> PracticeQuestion {
        let (options, answer) = makeOptions(correct: item.es,
                                            pool: distractors(for: item, primary: primary, fallback: fallback).map(\.es))
        let q = ChoiceQ(instruction: "用西班牙语怎么说？",
                        prompt: item.zh, promptSpanish: false,
                        options: options, optionsSpanish: true, answer: answer)
        return PracticeQuestion(kind: .choice(q), itemIds: [item.id])
    }

    static func listen(_ item: Item, primary: [Item], fallback: [Item]) -> PracticeQuestion {
        let (options, answer) = makeOptions(correct: item.es,
                                            pool: distractors(for: item, primary: primary, fallback: fallback).map(\.es))
        let q = ChoiceQ(instruction: "听一听，选出你听到的",
                        prompt: item.es, promptSpanish: true,
                        audioOnly: true, speak: item.speakText,
                        options: options, optionsSpanish: false, answer: answer,
                        explain: item.zh)
        return PracticeQuestion(kind: .choice(q), itemIds: [item.id])
    }

    static func dictation(_ item: Item) -> PracticeQuestion {
        let ex = TypeExercise(prompt: item.zh, answers: [item.es], display: item.es,
                              hint: nil, audio: item.speakText)
        return PracticeQuestion(kind: .type(ex), itemIds: [item.id])
    }

    private static func convert(_ exercise: AuthoredExercise) -> PracticeQuestion {
        switch exercise {
        case .build(let b):
            return PracticeQuestion(kind: .build(b), itemIds: [])
        case .type(let t):
            return PracticeQuestion(kind: .type(t), itemIds: [])
        case .fill(let f):
            let shuffled = f.options.shuffled()
            let answer = shuffled.firstIndex(of: f.answer) ?? 0
            let q = ChoiceQ(instruction: "选择正确的词填空",
                            prompt: f.sentence, promptSpanish: true,
                            sub: f.zh,
                            options: shuffled, optionsSpanish: true, answer: answer,
                            explain: f.explain,
                            reveal: f.sentence.replacingOccurrences(of: "___", with: f.answer))
            return PracticeQuestion(kind: .choice(q), itemIds: [])
        case .choice(let c):
            let order = Array(c.options.indices).shuffled()
            let options = order.map { c.options[$0] }
            let answer = order.firstIndex(of: c.answer) ?? 0
            let q = ChoiceQ(instruction: "选择正确答案",
                            prompt: c.question, promptSpanish: false,
                            sub: c.sub,
                            options: options, optionsSpanish: c.spanishOptions ?? false,
                            answer: answer, explain: c.explain)
            return PracticeQuestion(kind: .choice(q), itemIds: [])
        }
    }

    // MARK: Helpers

    private static func distractors(for item: Item, primary: [Item], fallback: [Item]) -> [Item] {
        let near = primary.filter { $0.id != item.id }.shuffled()
        let far = fallback.filter { $0.id != item.id && !primary.contains($0) }.shuffled()
        return near + far
    }

    /// Correct answer + up to 3 distinct distractors, shuffled.
    private static func makeOptions(correct: String, pool: [String]) -> ([String], Int) {
        var options = [correct]
        for candidate in pool where !options.contains(candidate) {
            options.append(candidate)
            if options.count == 4 { break }
        }
        options.shuffle()
        return (options, options.firstIndex(of: correct) ?? 0)
    }
}
