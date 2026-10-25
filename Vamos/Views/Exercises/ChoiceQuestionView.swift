import SwiftUI

struct ChoiceQuestionView: View {
    let q: ChoiceQ
    let onDone: (Bool) -> Void

    @AppStorage(Prefs.autoPlay) private var autoPlay = true
    @State private var selected: Int?
    @State private var checked = false
    @State private var praise = ""

    private var isCorrect: Bool { selected == q.answer }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    InstructionText(text: q.instruction)
                    promptView
                    VStack(spacing: 12) {
                        ForEach(q.options.indices, id: \.self) { i in
                            optionButton(i)
                        }
                    }
                }
                .padding(20)
            }
            FeedbackBar(state: feedback, onCheck: check, onContinue: { onDone(isCorrect) })
        }
        .onAppear {
            if autoPlay, let s = q.speak { TTS.shared.speak(s) }
        }
    }

    @ViewBuilder
    private var promptView: some View {
        if q.audioOnly {
            HStack(spacing: 16) {
                Button {
                    if let s = q.speak { TTS.shared.speak(s) }
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 96, height: 96)
                        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.vRojo))
                }
                .buttonStyle(.plain)
                if let s = q.speak { SlowSpeakButton(text: s, size: 60) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            if checked {
                Text(q.prompt)
                    .font(.spanish(22))
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    if q.promptSpanish, let s = checked ? (q.reveal ?? q.speak) : q.speak {
                        SpeakButton(text: s, size: 40)
                    }
                    Text(checked && q.reveal != nil ? q.reveal! : q.prompt)
                        .font(q.promptSpanish ? Font.spanish(26) : Font.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let sub = q.sub {
                    Text(sub)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private func optionButton(_ i: Int) -> some View {
        let isSelected = selected == i
        var border = Color.vLine
        var fill = Color.vCard
        if checked {
            if i == q.answer {
                border = .vOK; fill = Color.vOK.opacity(0.12)
            } else if isSelected {
                border = .vBad; fill = Color.vBad.opacity(0.10)
            }
        } else if isSelected {
            border = .vRojo; fill = Color.vRojo.opacity(0.08)
        }

        return Button {
            guard !checked else { return }
            Haptics.tap()
            selected = i
            if q.optionsSpanish { TTS.shared.speak(q.options[i]) }
        } label: {
            HStack(spacing: 12) {
                Text("\(i + 1)")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundColor(.vMuted)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.vLine, lineWidth: 1.5))
                Text(q.options[i])
                    .font(q.optionsSpanish ? Font.spanish(19, weight: .medium) : Font.body.weight(.medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(OptionButtonStyle(border: border, fill: fill))
    }

    private var feedback: FeedbackBar.Phase {
        guard checked else { return .idle(canCheck: selected != nil) }
        if isCorrect {
            return .correct(title: praise, detail: q.explain)
        }
        return .wrong(answer: q.options[q.answer], detail: q.explain)
    }

    private func check() {
        guard selected != nil else { return }
        praise = Praise.random()
        checked = true
        if isCorrect { Haptics.success() } else { Haptics.error() }
        if let reveal = q.reveal {
            TTS.shared.speak(reveal)
        } else if q.audioOnly, let s = q.speak, !isCorrect {
            TTS.shared.speak(s)
        }
    }
}
