import Foundation

// Shapes of the JSON the AI is asked to return. Optional fields keep decoding lenient.

struct DictionaryEntry: Codable {
    let word: String
    let lemma: String?
    let ipa: String?
    let pos: String?
    let forms: String?
    let meanings: [Meaning]
    let spain: String?
    let collocations: [String]?
    let synonyms: [String]?

    struct Meaning: Codable, Hashable {
        let zh: String
        let example_es: String?
        let example_zh: String?
    }
}

struct SentenceAnalysis: Codable {
    let translation: String
    let breakdown: [Chunk]?
    let grammar: [String]?
    let natural: [String]?
    let register: String?

    struct Chunk: Codable, Hashable {
        let es: String
        let zh: String
        let note: String?
    }
}

struct Conjugation: Codable {
    let infinitive: String
    let meaning: String?
    let gerund: String?
    let participle: String?
    let irregular: Bool?
    let notes: String?
    let tenses: [Tense]

    struct Tense: Codable, Hashable {
        let name: String
        let mood: String?
        let forms: [String]
    }
}

struct WritingFeedback: Codable {
    let score: Int?
    let level: String?
    let summary: String
    let corrected: String
    let native: String?
    let errors: [WritingError]?
    let vocab: [Pair]?

    struct WritingError: Codable, Hashable {
        let original: String
        let correction: String
        let explanation: String
        let type: String?
    }
}

struct Pair: Codable, Hashable {
    let es: String
    let zh: String
    var note: String? = nil
}

struct WritingTopic: Codable {
    let topic_es: String
    let topic_zh: String
}

struct ComprehensionQuestion: Codable, Hashable {
    let q: String
    let options: [String]
    let answer: Int
}

struct GradedReader: Codable {
    let title: String
    let text: String
    let glossary: [Pair]?
    let questions: [ComprehensionQuestion]?
}

struct NewsExplanation: Codable {
    let summary_zh: String
    let difficulty: String?
    let vocab: [Pair]?
    let expressions: [String]?
    let context: String?
}

struct ListeningScript: Codable {
    let title: String
    let situation_zh: String?
    let lines: [Line]
    let questions: [ComprehensionQuestion]?
    let vocab: [Pair]?

    struct Line: Codable, Hashable {
        let speaker: String
        let name: String?
        let text: String
    }
}

struct Correction: Codable, Hashable {
    let ok: Bool
    let corrected: String
    let explanation: String?
    let natural: String?
}

struct Suggestions: Codable {
    let suggestions: [Pair]
}

/// Small disk cache for AI lookups (dictionary entries, conjugations…).
enum AICache {
    private static var directory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ai-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func url(_ kind: String, _ key: String) -> URL {
        // FNV-1a hash keeps file names short and stable for any text.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return directory.appendingPathComponent("\(kind)-\(String(hash, radix: 16)).json")
    }

    static func load<T: Decodable>(_ type: T.Type, kind: String, key: String) -> T? {
        guard let data = try? Data(contentsOf: url(kind, key)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, kind: String, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: url(kind, key), options: .atomic)
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: directory)
    }
}

/// One-call helpers used by the tool screens.
enum AITasks {
    static func lookup(_ word: String, level: String) async throws -> DictionaryEntry {
        let key = word.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = AICache.load(DictionaryEntry.self, kind: "dict", key: key) { return cached }
        let entry = try await AIClient.shared.json(DictionaryEntry.self, system: Prompts.dictionarySystem(level: level),
                                                   prompt: "查询：\(key)", maxTokens: 2500, fast: true)
        AICache.save(entry, kind: "dict", key: key)
        return entry
    }

    static func analyze(_ text: String, level: String) async throws -> SentenceAnalysis {
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isChinese = key.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
        let kind = isChinese ? "zh2es" : "analyze"
        if let cached = AICache.load(SentenceAnalysis.self, kind: kind, key: key) { return cached }
        let system = isChinese ? Prompts.translateToSpanishSystem(level: level) : Prompts.analyzeSystem(level: level)
        let result = try await AIClient.shared.json(SentenceAnalysis.self, system: system, prompt: key, maxTokens: 3000)
        AICache.save(result, kind: kind, key: key)
        return result
    }

    static func conjugate(_ verb: String) async throws -> Conjugation {
        let key = verb.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let cached = AICache.load(Conjugation.self, kind: "conj", key: key) { return cached }
        let result = try await AIClient.shared.json(Conjugation.self, system: Prompts.conjugationSystem,
                                                    prompt: "动词：\(key)", maxTokens: 5000)
        AICache.save(result, kind: "conj", key: key)
        return result
    }

    static func translate(_ text: String) async throws -> String {
        if let cached = AICache.load(String.self, kind: "tr", key: text) { return cached }
        let result = try await AIClient.shared.complete(system: Prompts.translateSystem,
                                                        messages: [AIMessage(role: .user, content: text)],
                                                        maxTokens: 800, fast: true)
        let clean = result.trimmingCharacters(in: .whitespacesAndNewlines)
        AICache.save(clean, kind: "tr", key: text)
        return clean
    }
}
