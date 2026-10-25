import SwiftUI

/// Type the Spanish translation.
struct TypeQuestionView: View {
    let ex: TypeExercise
    let onDone: (Bool) -> Void

    @State private var text = ""
    @State private var verdict: AnswerChecker.Verdict?
    @State private var praise = ""
    @FocusState private var focused: Bool

    private let specials = ["á", "é", "í", "ó", "ú", "ñ", "ü", "¿", "¡"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    InstructionText(text: ex.audio == nil ? "用西班牙语写出来" : "听写：写下你听到的西语")
                    if let audio = ex.audio {
                        HStack(spacing: 16) {
                            Button { TTS.shared.speak(audio) } label: {
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 84, height: 84)
                                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.vRojo))
                            }
                            .buttonStyle(.plain)
                            SlowSpeakButton(text: audio, size: 56)
                        }
                        .frame(maxWidth: .infinity)
                        if verdict != nil {
                            Text(ex.prompt).font(.subheadline).foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ex.prompt)
                                .font(.title3.weight(.semibold))
                            if let hint = ex.hint {
                                Label(hint, systemImage: "lightbulb")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }

                    TextField("在这里输入…", text: $text)
                        .font(.spanish(21, weight: .regular))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .onSubmit {
                            if verdict == nil && !text.trimmingCharacters(in: .whitespaces).isEmpty { check() }
                        }
                        .focused($focused)
                        .disabled(verdict != nil)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.vSunken))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(focused ? Color.vRojo : Color.vLine, lineWidth: 2))

                    if verdict == nil {
                        HStack(spacing: 6) {
                            ForEach(specials, id: \.self) { ch in
                                Button {
                                    text.append(ch)
                                    Haptics.tap()
                                } label: {
                                    Text(ch)
                                        .font(.system(size: 19, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.vCard))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.vLine, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("小提示：标点和大小写不影响判分，重音写错会提醒但算对。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            FeedbackBar(state: feedback, onCheck: check, onContinue: { onDone(verdict != .wrong) })
        }
        .onAppear {
            if let audio = ex.audio, UserDefaults.standard.object(forKey: Prefs.autoPlay) as? Bool ?? true {
                TTS.shared.speak(audio)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }

    private var feedback: FeedbackBar.Phase {
        switch verdict {
        case nil:
            return .idle(canCheck: !text.trimmingCharacters(in: .whitespaces).isEmpty)
        case .correct?:
            return .correct(title: praise, detail: ex.displayAnswer)
        case .accentSlip?:
            return .correct(title: "差一点！注意重音 / ñ", detail: "正确写法：\(ex.displayAnswer)")
        case .wrong?:
            return .wrong(answer: ex.displayAnswer, detail: "你的答案：\(text)")
        }
    }

    private func check() {
        focused = false
        let result = AnswerChecker.check(text, answers: ex.answers)
        praise = Praise.random()
        verdict = result
        if result == .wrong { Haptics.error() } else { Haptics.success() }
        TTS.shared.speak(ex.displayAnswer)
    }
}
