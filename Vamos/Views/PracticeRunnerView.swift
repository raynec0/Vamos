import SwiftUI

final class PracticeSession: ObservableObject {
    @Published private(set) var queue: [PracticeQuestion]
    @Published private(set) var index = 0
    @Published private(set) var solved = 0
    let total: Int
    private var firstTryCorrect = 0
    private var missed: Set<String> = []

    init(questions: [PracticeQuestion]) {
        queue = questions
        total = questions.count
    }

    var current: PracticeQuestion? { index < queue.count ? queue[index] : nil }
    var progress: Double { total == 0 ? 1 : Double(solved) / Double(total) }

    var result: PracticeResult {
        PracticeResult(total: total, firstTryCorrect: firstTryCorrect, missedItemIds: missed)
    }

    func answer(correct: Bool, missedIds: [String] = []) {
        guard let q = current else { return }
        missed.formUnion(missedIds)
        if correct {
            solved += 1
            if !q.isRetry { firstTryCorrect += 1 }
        } else {
            missed.formUnion(q.itemIds)
            if q.repeatsWhenWrong {
                // Wrong answers come back at the end until they're right.
                queue.append(q.retry())
            } else {
                solved += 1
            }
        }
        index += 1
    }
}

/// Runs a list of questions with a progress bar; wrong answers are repeated at the end.
struct PracticeRunnerView: View {
    @StateObject private var session: PracticeSession
    let onClose: () -> Void
    let onFinish: (PracticeResult) -> Void

    @State private var confirmQuit = false

    init(questions: [PracticeQuestion], onClose: @escaping () -> Void, onFinish: @escaping (PracticeResult) -> Void) {
        _session = StateObject(wrappedValue: PracticeSession(questions: questions))
        self.onClose = onClose
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    confirmQuit = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.vMuted)
                }
                .buttonStyle(.plain)
                ProgressBar(value: session.progress)
                if let q = session.current, q.isRetry {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundColor(.vOro)
                        .help("再试一次")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if let q = session.current {
                questionView(q)
                    .id(q.id)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity))
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .background(Color.vBackground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: session.index)
        .confirmationDialog("确定要退出吗？本次进度不会保存。", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("退出", role: .destructive, action: onClose)
            Button("继续练习", role: .cancel) {}
        }
        .onChange(of: session.index) { _ in
            if session.current == nil { onFinish(session.result) }
        }
        .onAppear {
            if session.current == nil { onFinish(session.result) }
        }
    }

    @ViewBuilder
    private func questionView(_ q: PracticeQuestion) -> some View {
        switch q.kind {
        case .choice(let c):
            ChoiceQuestionView(q: c) { ok in session.answer(correct: ok) }
        case .build(let b):
            BuildQuestionView(ex: b) { ok in session.answer(correct: ok) }
        case .type(let t):
            TypeQuestionView(ex: t) { ok in session.answer(correct: ok) }
        case .match(let items):
            MatchQuestionView(items: items) { missed in session.answer(correct: true, missedIds: missed) }
        case .speak(let item):
            SpeakQuestionView(item: item) { ok in session.answer(correct: ok) }
        }
    }
}
