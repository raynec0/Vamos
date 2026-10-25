import AVFoundation

/// Text-to-speech with Castilian Spanish (es-ES) voices.
final class TTS: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TTS()

    private let synthesizer = AVSpeechSynthesizer()

    /// All es-ES voices, best quality first.
    static var spanishVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "es-ES" }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
    }

    private(set) lazy var voice: AVSpeechSynthesisVoice? = {
        Self.spanishVoices.first ?? AVSpeechSynthesisVoice(language: "es-ES")
    }()

    /// A second, different voice for dialogues (falls back to the main voice).
    var secondVoice: AVSpeechSynthesisVoice? {
        let voices = Self.spanishVoices
        return voices.first { $0.identifier != voice?.identifier && $0.gender != voice?.gender }
            ?? voices.first { $0.identifier != voice?.identifier }
            ?? voice
    }

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    var voiceName: String {
        guard let v = voice else { return "未找到 es-ES 语音" }
        return "\(v.name)（\(Self.qualityName(v))）"
    }

    static func qualityName(_ v: AVSpeechSynthesisVoice) -> String {
        switch v.quality {
        case .enhanced: return "增强"
        case .premium: return "高级"
        default: return "标准"
        }
    }

    static var baseRate: Double {
        UserDefaults.standard.object(forKey: Prefs.speechRate) as? Double ?? Prefs.defaultSpeechRate
    }

    static func activatePlayback() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    func speak(_ text: String, slow: Bool = false) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        Self.activatePlayback()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = voice
        utterance.rate = Float(slow ? Self.baseRate * 0.65 : Self.baseRate)
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Plays a list of lines one after another (two voices for dialogues) and reports which line is playing.
final class LinePlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    struct Line {
        let text: String
        let secondVoice: Bool
    }

    @Published private(set) var currentIndex: Int?
    @Published private(set) var isPlaying = false

    private let synthesizer = AVSpeechSynthesizer()
    private var indexByUtterance: [ObjectIdentifier: Int] = [:]

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func play(_ lines: [Line], from start: Int = 0, slow: Bool = false) {
        stop()
        guard start < lines.count else { return }
        TTS.shared.stop()
        TTS.activatePlayback()
        let first = TTS.shared.voice
        let second = TTS.shared.secondVoice
        for i in start..<lines.count {
            let u = AVSpeechUtterance(string: lines[i].text)
            u.voice = lines[i].secondVoice ? second : first
            u.rate = Float(slow ? TTS.baseRate * 0.7 : TTS.baseRate)
            u.postUtteranceDelay = 0.35
            indexByUtterance[ObjectIdentifier(u)] = i
            synthesizer.speak(u)
        }
        isPlaying = true
    }

    func playOne(_ line: Line, index: Int, slow: Bool = false) {
        play([line], from: 0, slow: slow)
        currentIndex = index
        indexByUtterance = indexByUtterance.mapValues { _ in index }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        indexByUtterance = [:]
        currentIndex = nil
        isPlaying = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let index = indexByUtterance[ObjectIdentifier(utterance)]
        DispatchQueue.main.async { if index != nil { self.currentIndex = index } }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        indexByUtterance[ObjectIdentifier(utterance)] = nil
        if indexByUtterance.isEmpty {
            DispatchQueue.main.async {
                self.isPlaying = false
                self.currentIndex = nil
            }
        }
    }
}
