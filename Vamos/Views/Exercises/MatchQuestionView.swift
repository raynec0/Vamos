import SwiftUI

/// Tap a Spanish card, then its Chinese meaning.
struct MatchQuestionView: View {
    let items: [Item]
    /// Reports the ids of items the learner mismatched.
    let onDone: ([String]) -> Void

    @State private var left: [Item]
    @State private var right: [Item]
    @State private var pickedLeft: String?
    @State private var pickedRight: String?
    @State private var matched: Set<String> = []
    @State private var flashing: Set<String> = []
    @State private var missed: Set<String> = []

    init(items: [Item], onDone: @escaping ([String]) -> Void) {
        self.items = items
        self.onDone = onDone
        _left = State(initialValue: items.shuffled())
        _right = State(initialValue: items.shuffled())
    }

    private var finished: Bool { matched.count == items.count }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    InstructionText(text: "配对：西语和中文")
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 10) {
                            ForEach(left) { item in
                                card(text: item.es, key: "L" + item.id, id: item.id,
                                     selected: pickedLeft == item.id, spanish: true) {
                                    TTS.shared.speak(item.speakText)
                                    pickedLeft = item.id
                                    evaluate()
                                }
                            }
                        }
                        VStack(spacing: 10) {
                            ForEach(right) { item in
                                card(text: item.zh, key: "R" + item.id, id: item.id,
                                     selected: pickedRight == item.id, spanish: false) {
                                    pickedRight = item.id
                                    evaluate()
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            if finished {
                FeedbackBar(state: .correct(title: missed.isEmpty ? "全部配对，一次都没错！" : "全部配对完成",
                                            detail: nil),
                            onCheck: {}, onContinue: { onDone(Array(missed)) })
            }
        }
    }

    private func card(text: String, key: String, id: String, selected: Bool, spanish: Bool,
                      action: @escaping () -> Void) -> some View {
        let done = matched.contains(id)
        let wrong = flashing.contains(key)
        let border: Color = wrong ? .vBad : (selected ? .vRojo : (done ? Color.vOK.opacity(0.4) : Color.vLine))
        let fill: Color = wrong ? Color.vBad.opacity(0.1)
            : (selected ? Color.vRojo.opacity(0.08) : (done ? Color.vOK.opacity(0.08) : Color.vCard))

        return Button {
            guard !done else { return }
            Haptics.tap()
            action()
        } label: {
            Text(text)
                .font(spanish ? Font.spanish(17, weight: .medium) : Font.subheadline.weight(.medium))
                .foregroundColor(done ? .secondary : .primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 58)
                .padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: 2))
                .opacity(done ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(done)
    }

    private func evaluate() {
        guard let l = pickedLeft, let r = pickedRight else { return }
        if l == r {
            withAnimation(.easeOut(duration: 0.2)) { _ = matched.insert(l) }
            pickedLeft = nil
            pickedRight = nil
            if matched.count == items.count { Haptics.success() }
        } else {
            Haptics.error()
            missed.insert(l)
            missed.insert(r)
            let keys: Set<String> = ["L" + l, "R" + r]
            withAnimation { flashing.formUnion(keys) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation { flashing.subtract(keys) }
                pickedLeft = nil
                pickedRight = nil
            }
        }
    }
}
