import SwiftUI

/// One lesson: grammar notes → new words → practice → summary.
struct LessonFlowView: View {
    let lesson: Lesson
    let entry: LessonEntry
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case tips, learn, practice, done }

    @State private var phase: Phase
    @State private var learnIndex = 0
    @State private var questions: [PracticeQuestion] = []
    @State private var result: PracticeResult?
    @State private var xpGained = 0
    @State private var chatSession: ChatSession?
    @State private var confirmRegenerate = false

    init(lesson: Lesson, entry: LessonEntry) {
        self.lesson = lesson
        self.entry = entry
        _phase = State(initialValue: lesson.tips.isEmpty ? .learn : .tips)
    }

    private var accent: Color { Color.unit(entry.color) }

    var body: some View {
        Group {
            switch phase {
            case .tips:
                TipsPage(lesson: lesson, accent: accent, isAI: entry.isAI, onClose: { dismiss() },
                         onRegenerate: { confirmRegenerate = true }) {
                    withAnimation { phase = .learn }
                }
            case .learn:
                LearnPage(lesson: lesson, accent: accent, index: $learnIndex,
                          onClose: { dismiss() },
                          onBack: lesson.tips.isEmpty ? nil : { withAnimation { phase = .tips } }) {
                    questions = PracticeBuilder.questions(for: lesson, levelId: entry.levelId)
                    withAnimation { phase = .practice }
                }
            case .practice:
                PracticeRunnerView(questions: questions, onClose: { dismiss() }) { r in
                    result = r
                    xpGained = progress.completeLesson(lesson, result: r)
                    withAnimation { phase = .done }
                }
            case .done:
                CompletionView(
                    title: (result?.accuracy ?? 0) >= 0.9 ? "¡Excelente!" : "¡Bien hecho!",
                    subtitle: "「\(lesson.title)」完成了\n新词句已加入复习卡片",
                    stats: [
                        (icon: "bolt.fill", value: "+\(xpGained)", label: "经验", color: Color.vOro),
                        (icon: "target", value: "\(Int(((result?.accuracy ?? 0) * 100).rounded()))%", label: "一次答对", color: Color.vOK),
                        (icon: "rectangle.stack.fill", value: "\(lesson.items.count)", label: "词句", color: accent)
                    ],
                    buttonTitle: "继续",
                    onDone: { dismiss() },
                    secondaryTitle: AIClient.shared.isConfigured ? "用本课内容和 AI 对话练习" : nil,
                    onSecondary: {
                        let scenario = ChatScenario.forLesson(entry)
                        chatSession = ChatStore.shared.create(scenario: scenario, level: entry.levelId)
                    }
                )
            }
        }
        .background(Color.vBackground.ignoresSafeArea())
        .onDisappear { TTS.shared.stop() }
        .fullScreenCover(item: $chatSession) { s in
            ChatView(session: s).environmentObject(progress)
        }
        .confirmationDialog("删除这节课的 AI 内容并重新生成？", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("重新生成", role: .destructive) {
                LessonRepository.shared.discard(entry)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("如果发现讲解或例句有问题，可以让 AI 重写。下次打开这节课时会重新生成。")
        }
    }
}

// MARK: - Grammar notes

private struct TipsPage: View {
    let lesson: Lesson
    let accent: Color
    let isAI: Bool
    let onClose: () -> Void
    let onRegenerate: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            CloseHeader(title: "讲解", onClose: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lesson.subtitle)
                            .font(.spanish(30, weight: .bold))
                            .foregroundColor(accent)
                        Text(lesson.title)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 4)

                    ForEach(lesson.tips, id: \.self) { tip in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 4, height: 18)
                                Text(tip.title).font(.headline)
                            }
                            Text(tip.body)
                                .font(.body)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }
                    if isAI {
                        Button(action: onRegenerate) {
                            Label("本课由 AI 生成。内容有问题？点这里重新生成", systemImage: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            Button("学习新词句（\(lesson.items.count)）", action: onNext)
                .buttonStyle(ChunkyButtonStyle(color: accent))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
    }
}

// MARK: - New words, one card at a time

private struct LearnPage: View {
    let lesson: Lesson
    let accent: Color
    @Binding var index: Int
    let onClose: () -> Void
    let onBack: (() -> Void)?
    let onFinish: () -> Void

    @AppStorage(Prefs.autoPlay) private var autoPlay = true

    private var item: Item { lesson.items[min(index, lesson.items.count - 1)] }
    private var isLast: Bool { index >= lesson.items.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            CloseHeader(title: "新词句 \(index + 1) / \(lesson.items.count)", onClose: onClose)
            ProgressBar(value: Double(index + 1) / Double(max(1, lesson.items.count)), color: accent)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 14) {
                    ItemCard(item: item, accent: accent)
                        .id(item.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .opacity))
                    if !item.isPair {
                        InlineSpeakingCard(text: item.speakText)
                            .id("speak-" + item.id)
                    }
                }
                .padding(20)
            }

            HStack(spacing: 12) {
                Button {
                    if index > 0 { withAnimation { index -= 1 } } else { onBack?() }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(ChunkyButtonStyle(color: .vCard, foreground: .primary, enabled: index > 0 || onBack != nil))
                .disabled(!(index > 0 || onBack != nil))
                .frame(width: 80)

                Button(isLast ? "开始练习" : "下一个") {
                    if isLast { onFinish() } else { withAnimation { index += 1 } }
                }
                .buttonStyle(ChunkyButtonStyle(color: isLast ? .vOK : accent))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .onAppear { if autoPlay { TTS.shared.speak(item.speakText) } }
        .onChange(of: index) { _ in
            if autoPlay { TTS.shared.speak(item.speakText) }
        }
    }
}

/// Spanish · Chinese · grammar · pronunciation.
struct ItemCard: View {
    let item: Item
    var accent: Color = .vRojo

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(item.es)
                    .font(.spanish(34, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.zh)
                    .font(.title3)
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    SpeakButton(text: item.speakText, size: 52, color: accent)
                    SlowSpeakButton(text: item.speakText, size: 52)
                }
                .padding(.top, 4)
            }
            if let note = item.note {
                infoRow(icon: "book.closed.fill", title: "语法", text: note, color: Color.unit("azul"))
            }
            if let pron = item.pron {
                infoRow(icon: "mouth.fill", title: "发音", text: pron, color: Color.unit("oro"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func infoRow(icon: String, title: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 30, height: 30)
                .background(Circle().fill(color.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption.weight(.bold)).foregroundColor(color)
                Text(text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CloseHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.vMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// Small "repeat after me" box under a new word.
struct InlineSpeakingCard: View {
    let text: String
    @StateObject private var recognizer = SpeechRecognizer()
    @State private var result: (words: [AnswerChecker.WordMatch], score: Double)?
    @State private var heard = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MicButton(recognizer: recognizer, size: 44) { h in
                    heard = h
                    result = AnswerChecker.pronunciation(target: text, heard: h)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("跟读一下").font(.subheadline.weight(.semibold))
                    Text(recognizer.isRecording ? (recognizer.transcript.isEmpty ? "正在听…说完再点一下" : recognizer.transcript)
                                                : "点麦克风，说出上面的西语")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            if let e = recognizer.errorMessage {
                Text(e).font(.caption).foregroundColor(.vBad)
            }
            if let r = result {
                PronunciationResultView(words: r.words, score: r.score, heard: heard)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .onDisappear { recognizer.stop() }
    }
}
