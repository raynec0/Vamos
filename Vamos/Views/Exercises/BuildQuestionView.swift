import SwiftUI

/// Tap word tiles to put a sentence together.
struct BuildQuestionView: View {
    let ex: BuildExercise
    let onDone: (Bool) -> Void

    private struct Tile: Identifiable {
        let id: Int
        let text: String
    }

    @State private var bank: [Tile]
    @State private var chosen: [Int] = []
    @State private var checked = false
    @State private var correct = false
    @State private var praise = ""

    init(ex: BuildExercise, onDone: @escaping (Bool) -> Void) {
        self.ex = ex
        self.onDone = onDone
        let words = (ex.answer + (ex.distractors ?? [])).shuffled()
        _bank = State(initialValue: words.enumerated().map { Tile(id: $0.offset, text: $0.element) })
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    InstructionText(text: "把句子翻译成西班牙语")
                    Text(ex.prompt)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()

                    // Answer line
                    FlowLayout(spacing: 8, lineSpacing: 10) {
                        ForEach(chosen, id: \.self) { id in
                            if let tile = bank.first(where: { $0.id == id }) {
                                tileView(tile.text, style: .chosen)
                                    .onTapGesture {
                                        guard !checked else { return }
                                        Haptics.tap()
                                        chosen.removeAll { $0 == id }
                                    }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                    .padding(12)
                    .background(
                        VStack(spacing: 52) {
                            Rectangle().fill(Color.vLine).frame(height: 1.5)
                            Rectangle().fill(Color.vLine).frame(height: 1.5)
                        }
                        .padding(.top, 40),
                        alignment: .top
                    )

                    // Word bank
                    FlowLayout(spacing: 8, lineSpacing: 10) {
                        ForEach(bank) { tile in
                            let used = chosen.contains(tile.id)
                            tileView(tile.text, style: used ? .placeholder : .bank)
                                .onTapGesture {
                                    guard !checked, !used else { return }
                                    Haptics.tap()
                                    TTS.shared.speak(tile.text)
                                    chosen.append(tile.id)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
            }
            FeedbackBar(state: feedback, onCheck: check, onContinue: { onDone(correct) })
        }
    }

    private enum TileStyle { case bank, chosen, placeholder }

    private func tileView(_ text: String, style: TileStyle) -> some View {
        Text(text)
            .font(.spanish(19, weight: .medium))
            .foregroundColor(style == .placeholder ? .clear : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(style == .placeholder ? Color.vSunken : Color.vCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(style == .placeholder ? Color.clear : Color.vLine, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(style == .placeholder ? Color.clear : Color.vLine)
                    .offset(y: 3)
            )
    }

    private var feedback: FeedbackBar.Phase {
        guard checked else { return .idle(canCheck: !chosen.isEmpty) }
        return correct ? .correct(title: praise, detail: ex.full) : .wrong(answer: ex.full, detail: nil)
    }

    private func check() {
        let words = chosen.compactMap { id in bank.first(where: { $0.id == id })?.text }
        correct = AnswerChecker.sameTokens(words, ex.answer)
        praise = Praise.random()
        checked = true
        if correct { Haptics.success() } else { Haptics.error() }
        TTS.shared.speak(ex.full)
    }
}
