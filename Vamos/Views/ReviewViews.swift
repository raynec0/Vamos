import SwiftUI

// MARK: - Review tab

struct ReviewHomeView: View {
    @EnvironmentObject private var progress: ProgressStore
    @State private var reviewing = false
    @State private var practicing = false
    @State private var practiceQuestions: [PracticeQuestion] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dueCard
                    statsRow
                    practiceCard
                    if !progress.troubleItems.isEmpty { troubleCard }
                    explainer
                }
                .padding(16)
            }
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle("复习")
        }
        .fullScreenCover(isPresented: $reviewing) {
            ReviewSessionView(cards: progress.dueCards().prefix(40).map(\.itemId))
                .environmentObject(progress)
        }
        .fullScreenCover(isPresented: $practicing) {
            FreePracticeView(questions: practiceQuestions)
                .environmentObject(progress)
        }
    }

    private var dueCard: some View {
        let due = progress.dueCount
        return VStack(spacing: 14) {
            Text(due > 0 ? "\(due)" : "✓")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(due > 0 ? .vRojo : .vOK)
            Text(due > 0 ? "张卡片等待复习" : (progress.data.cards.isEmpty ? "学完第一课后，这里会出现复习卡片" : "今天的复习都完成了 ¡Genial!"))
                .font(.headline)
                .multilineTextAlignment(.center)
            if due > 0 {
                Button("开始复习") { reviewing = true }
                    .buttonStyle(ChunkyButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .card()
    }

    private var statsRow: some View {
        let total = progress.data.cards.count
        let mastered = progress.masteredCount
        return HStack(spacing: 12) {
            stat("\(total)", "已学词句", Color.unit("azul"))
            stat("\(total - mastered)", "学习中", Color.unit("oro"))
            stat("\(mastered)", "已掌握", .vOK)
        }
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var practiceCard: some View {
        let items = progress.learnedItems
        return VStack(alignment: .leading, spacing: 10) {
            Label("自由练习", systemImage: "dumbbell.fill")
                .font(.headline)
            Text("从已学内容里随机出 10 道题：看词选义、听音辨词、配对。做错的会自动加入复习。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(items.count >= 4 ? "来一组" : "至少学完一课后开放") {
                practiceQuestions = PracticeBuilder.freePractice(from: items)
                practicing = !practiceQuestions.isEmpty
            }
            .buttonStyle(ChunkyButtonStyle(color: Color.unit("azul"), enabled: items.count >= 4))
            .disabled(items.count < 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var troubleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("易错词句", systemImage: "exclamationmark.bubble.fill")
                .font(.headline)
                .foregroundColor(.vBad)
            ForEach(progress.troubleItems) { item in
                HStack(spacing: 12) {
                    SpeakButton(text: item.speakText, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.es).font(.spanish(17))
                        Text(item.zh).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if let lapses = progress.card(for: item.id)?.lapses {
                        Text("忘了 \(lapses) 次")
                            .font(.caption2)
                            .foregroundColor(.vMuted)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var explainer: some View {
        Text("复习采用间隔重复：记得越牢，下次出现的间隔越长（1 天 → 3 天 → 1 周 → 1 个月……）。每天清空待复习卡片，是记住单词最省力的办法。")
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
    }
}

// MARK: - Flashcard session

struct ReviewSessionView: View {
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.reviewDirection) private var directionRaw = ReviewDirection.esToZh.rawValue
    @AppStorage(Prefs.autoPlay) private var autoPlay = true

    @State private var queue: [String]
    @State private var index = 0
    @State private var revealed = false
    @State private var reviewedCount = 0
    @State private var forgotCount = 0
    @State private var spanishFront = true
    @State private var initialCount: Int

    init(cards: [String]) {
        _queue = State(initialValue: cards)
        _initialCount = State(initialValue: cards.count)
    }

    private var currentItem: Item? {
        guard index < queue.count else { return nil }
        return CourseStore.shared.item(queue[index])
    }

    var body: some View {
        Group {
            if let item = currentItem {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.vMuted)
                        }
                        .buttonStyle(.plain)
                        ProgressBar(value: Double(min(reviewedCount, initialCount)) / Double(max(1, initialCount)),
                                    color: .vRojo)
                        Text("\(max(0, queue.count - index))")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    ScrollView {
                        flashcard(item)
                            .id("\(index)-\(item.id)")
                            .padding(20)
                    }

                    bottomBar(item)
                }
                .onAppear { prepare(item) }
                .onChange(of: index) { _ in
                    if let next = currentItem { prepare(next) }
                }
            } else {
                CompletionView(
                    title: "¡Hecho!",
                    subtitle: "复习完成，明天见",
                    stats: [
                        (icon: "rectangle.stack.fill", value: "\(initialCount)", label: "复习卡片", color: Color.vRojo),
                        (icon: "arrow.uturn.backward", value: "\(forgotCount)", label: "重来次数", color: Color.vOro)
                    ],
                    buttonTitle: "完成",
                    onDone: { dismiss() }
                )
            }
        }
        .background(Color.vBackground.ignoresSafeArea())
        .onDisappear { TTS.shared.stop() }
    }

    private func prepare(_ item: Item) {
        revealed = false
        switch ReviewDirection(rawValue: directionRaw) ?? .esToZh {
        case .esToZh: spanishFront = true
        case .zhToEs: spanishFront = false
        case .mixed: spanishFront = Bool.random()
        }
        if spanishFront && autoPlay { TTS.shared.speak(item.speakText) }
    }

    private func flashcard(_ item: Item) -> some View {
        VStack(spacing: 20) {
            Text(spanishFront ? "这是什么意思？" : "用西班牙语怎么说？")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            if spanishFront {
                Text(item.es)
                    .font(.spanish(34, weight: .bold))
                    .multilineTextAlignment(.center)
                SpeakButton(text: item.speakText, size: 48)
            } else {
                Text(item.zh)
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
            }

            if revealed {
                Divider()
                if spanishFront {
                    Text(item.zh)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                } else {
                    Text(item.es)
                        .font(.spanish(32, weight: .bold))
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        SpeakButton(text: item.speakText, size: 48)
                        SlowSpeakButton(text: item.speakText, size: 48)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    if let note = item.note {
                        Label(note, systemImage: "book.closed.fill")
                            .font(.footnote)
                    }
                    if let pron = item.pron {
                        Label(pron, systemImage: "mouth.fill")
                            .font(.footnote)
                    }
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .card()
    }

    @ViewBuilder
    private func bottomBar(_ item: Item) -> some View {
        Group {
            if revealed, let card = progress.card(for: item.id) {
                HStack(spacing: 8) {
                    ForEach(ReviewRating.allCases, id: \.self) { rating in
                        Button {
                            rate(item, rating)
                        } label: {
                            VStack(spacing: 2) {
                                Text(rating.title).font(.subheadline.weight(.bold))
                                Text(SRS.label(for: card, rating: rating))
                                    .font(.caption2)
                                    .opacity(0.85)
                            }
                        }
                        .buttonStyle(ChunkyButtonStyle(color: color(for: rating)))
                    }
                }
            } else {
                Button("显示答案") {
                    withAnimation(.easeOut(duration: 0.2)) { revealed = true }
                    if !spanishFront { TTS.shared.speak(item.speakText) }
                }
                .buttonStyle(ChunkyButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func color(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: return .vBad
        case .hard: return Color.unit("oro")
        case .good: return .vOK
        case .easy: return Color.unit("azul")
        }
    }

    private func rate(_ item: Item, _ rating: ReviewRating) {
        Haptics.tap()
        progress.review(itemId: item.id, rating: rating)
        if rating == .again {
            forgotCount += 1
            queue.append(item.id)   // see it again this session
        } else {
            reviewedCount += 1
        }
        index += 1
    }
}

// MARK: - Free practice

struct FreePracticeView: View {
    let questions: [PracticeQuestion]
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var result: PracticeResult?

    var body: some View {
        if let result {
            CompletionView(
                title: "¡Muy bien!",
                subtitle: "自由练习完成",
                stats: [
                    (icon: "bolt.fill", value: "+\(result.firstTryCorrect)", label: "经验", color: Color.vOro),
                    (icon: "target", value: "\(Int((result.accuracy * 100).rounded()))%", label: "一次答对", color: Color.vOK)
                ],
                buttonTitle: "完成",
                onDone: { dismiss() }
            )
        } else {
            PracticeRunnerView(questions: questions, onClose: { dismiss() }) { r in
                progress.recordPractice(r)
                withAnimation { result = r }
            }
        }
    }
}
