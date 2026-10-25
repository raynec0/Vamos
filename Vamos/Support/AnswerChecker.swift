import Foundation

enum AnswerChecker {
    enum Verdict: Equatable {
        case correct
        /// Right apart from accents / ñ — counted as correct, with a reminder.
        case accentSlip
        case wrong
    }

    private static let punctuation = CharacterSet(charactersIn: "¿?¡!.,;:\"'«»“”‘’…()-–—")

    static func stripPunctuation(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { !punctuation.contains($0) }))
    }

    static func normalize(_ text: String, foldAccents: Bool) -> String {
        var t = stripPunctuation(text.lowercased())
        if foldAccents {
            t = t.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
        }
        return t.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Words of a sentence without punctuation, original case kept.
    static func tokens(_ sentence: String) -> [String] {
        stripPunctuation(sentence).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    static func check(_ input: String, answers: [String]) -> Verdict {
        let exact = normalize(input, foldAccents: false)
        guard !exact.isEmpty else { return .wrong }
        if answers.contains(where: { normalize($0, foldAccents: false) == exact }) {
            return .correct
        }
        let loose = normalize(input, foldAccents: true)
        if answers.contains(where: { normalize($0, foldAccents: true) == loose }) {
            return .accentSlip
        }
        return .wrong
    }

    /// Compares word tiles ignoring case.
    static func sameTokens(_ a: [String], _ b: [String]) -> Bool {
        a.map { $0.lowercased() } == b.map { $0.lowercased() }
    }

    // MARK: Pronunciation scoring

    struct WordMatch: Identifiable {
        let id: Int
        let word: String
        let matched: Bool
    }

    /// Aligns the target sentence with what speech recognition heard (longest common subsequence,
    /// accent-insensitive). Returns per-word results and a 0–1 score.
    static func pronunciation(target: String, heard: String) -> (words: [WordMatch], score: Double) {
        let targetWords = tokens(target)
        let a = targetWords.map { normalize($0, foldAccents: true) }
        let b = tokens(heard).map { normalize($0, foldAccents: true) }
        guard !a.isEmpty else { return ([], 0) }

        var dp = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        if !b.isEmpty {
            for i in stride(from: a.count - 1, through: 0, by: -1) {
                for j in stride(from: b.count - 1, through: 0, by: -1) {
                    dp[i][j] = similar(a[i], b[j]) ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }
        var matched = Set<Int>()
        var i = 0, j = 0
        while i < a.count && j < b.count {
            if similar(a[i], b[j]) {
                matched.insert(i); i += 1; j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        let words = targetWords.enumerated().map { WordMatch(id: $0.offset, word: $0.element, matched: matched.contains($0.offset)) }
        return (words, Double(matched.count) / Double(a.count))
    }

    /// Exact match, or one small slip in a longer word (recognizers often drop a letter).
    private static func similar(_ x: String, _ y: String) -> Bool {
        if x == y { return true }
        guard x.count >= 7, abs(x.count - y.count) <= 1 else { return false }
        return editDistance(x, y) <= 1
    }

    private static func editDistance(_ s: String, _ t: String) -> Int {
        let a = Array(s), b = Array(t)
        var prev = Array(0...b.count)
        for i in 1...max(1, a.count) where !a.isEmpty {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in stride(from: 1, through: b.count, by: 1) {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return a.isEmpty ? b.count : prev[b.count]
    }
}
