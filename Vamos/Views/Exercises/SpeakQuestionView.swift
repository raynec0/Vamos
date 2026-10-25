import SwiftUI

/// Say the sentence out loud; speech recognition scores each word.
struct SpeakQuestionView: View {
    let item: Item
    let onDone: (Bool) -> Void

    @StateObject private var recognizer = SpeechRecognizer()
    @State private var result: (words: [AnswerChecker.WordMatch], score: Double)?
    @State private var heard = ""
    @State private var attempts = 0

    private var passed: Bool { (result?.score ?? 0) >= 0.6 }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    InstructionText(text: "大声读出来")
                    VStack(spacing: 10) {
                        Text(item.es)
                            .font(.spanish(28, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text(item.zh).font(.subheadline).foregroundColor(.secondary)
                        HStack(spacing: 14) {
                            SpeakButton(text: item.speakText, size: 44)
                            SlowSpeakButton(text: item.speakText, size: 44)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .card()

                    MicButton(recognizer: recognizer, size: 76) { h in
                        heard = h
                        attempts += 1
                        let r = AnswerChecker.pronunciation(target: item.es, heard: h)
                        result = r
                        if r.score >= 0.6 { Haptics.success() } else { Haptics.error() }
                    }
                    Text(recognizer.isRecording ? (recognizer.transcript.isEmpty ? "正在听…说完再点一下" : recognizer.transcript)
                                                : "点麦克风开始说")
                        .font(.subheadline).foregroundColor(.secondary)
                    if let e = recognizer.errorMessage {
                        Text(e).font(.caption).foregroundColor(.vBad).multilineTextAlignment(.center)
                    }
                    if let r = result {
                        PronunciationResultView(words: r.words, score: r.score, heard: heard)
                    }
                }
                .padding(20)
            }
            VStack(spacing: 8) {
                if passed {
                    Button("继续") { onDone(true) }
                        .buttonStyle(ChunkyButtonStyle(color: .vOK))
                } else if attempts >= 3 {
                    Button("先跳过，下次再练") { onDone(false) }
                        .buttonStyle(ChunkyButtonStyle(color: .vOro))
                }
                if !passed {
                    Button("现在不方便说话") { onDone(true) }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .onDisappear { recognizer.stop() }
    }
}
