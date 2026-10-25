import SwiftUI

// MARK: - Chat tab

struct ChatHomeView: View {
    @EnvironmentObject private var progress: ProgressStore
    @ObservedObject private var store = ChatStore.shared
    @State private var openSession: ChatSession?
    @State private var levelFilter: String = "全部"

    private var levels: [String] { ["全部"] + CourseStore.shared.levels.map(\.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !AIClient.shared.isConfigured {
                        AISetupPrompt(message: "AI 对话练习需要连接 AI。").card()
                    }

                    Button {
                        start(.tutor)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.wave.2.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                                .background(Circle().fill(Color.vRojo))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("和 Lucía 自由聊天").font(.headline).foregroundColor(.primary)
                                Text("马德里的西语老师，会按你的水平（\(progress.learnerLevel)）说话")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.vMuted)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)

                    if !store.sessions.isEmpty {
                        Text("最近的对话").font(.headline)
                        ForEach(store.sessions.prefix(5)) { s in
                            Button { openSession = s } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: s.scenario.icon)
                                        .foregroundColor(.vRojo)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.scenario.title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                                        Text(s.preview).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(s.updated, style: .relative).font(.caption2).foregroundColor(.vMuted)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("删除", role: .destructive) { store.delete(s.id) }
                            }
                        }
                    }

                    HStack {
                        Text("情景对话").font(.headline)
                        Spacer()
                        Picker("级别", selection: $levelFilter) {
                            ForEach(levels, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    ForEach(ChatScenario.all.filter { levelFilter == "全部" || $0.level == levelFilter }) { scenario in
                        Button { start(scenario) } label: { scenarioRow(scenario) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle("对话")
            .fullScreenCover(item: $openSession) { s in
                ChatView(session: s)
                    .environmentObject(progress)
            }
        }
    }

    private func scenarioRow(_ s: ChatScenario) -> some View {
        let color = Color.unit(CourseStore.shared.level(s.level)?.color ?? "rojo")
        return HStack(spacing: 14) {
            Image(systemName: s.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(color))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(s.title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                    Text(s.level)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(color.opacity(0.15)))
                        .foregroundColor(color)
                }
                Text(s.goal).font(.caption).foregroundColor(.secondary).lineLimit(2)
            }
            Spacer()
        }
        .card()
    }

    private func start(_ scenario: ChatScenario) {
        let level = scenario.level.isEmpty ? progress.learnerLevel : scenario.level
        openSession = store.create(scenario: scenario, level: level)
    }
}

// MARK: - Conversation

final class ChatViewModel: ObservableObject {
    @Published var session: ChatSession
    @Published var streaming: String?
    @Published var error: String?
    @Published var correcting: Set<UUID> = []
    @Published var translating: Set<UUID> = []

    private var replyTask: Task<Void, Never>?

    init(session: ChatSession) {
        self.session = session
    }

    var scenario: ChatScenario { session.scenario }
    var isBusy: Bool { streaming != nil }

    /// Builds the history for the API: a hidden opening instruction, then alternating turns.
    private func history() -> [AIMessage] {
        var list = [AIMessage(role: .user, content: Prompts.chatOpening(scenario: scenario))]
        for m in session.messages {
            if let last = list.last, last.role == m.role {
                list[list.count - 1].content += "\n" + m.text
            } else {
                list.append(AIMessage(role: m.role, content: m.text))
            }
        }
        return list
    }

    func startIfNeeded() {
        if session.messages.isEmpty && AIClient.shared.isConfigured { requestReply() }
    }

    func send(_ text: String, corrections: Bool) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isBusy else { return }
        let context = session.messages.last(where: { $0.role == .assistant })?.text ?? ""
        let message = ChatMessage(role: .user, text: clean)
        session.messages.append(message)
        persist()
        if corrections { correct(message.id, text: clean, context: context) }
        requestReply()
    }

    func requestReply(autoSpeak: Bool = UserDefaults.standard.object(forKey: Prefs.chatAutoSpeak) as? Bool ?? true) {
        error = nil
        streaming = ""
        let system = Prompts.chatSystem(scenario: scenario, level: session.level)
        let messages = history()
        replyTask = Task {
            var text = ""
            do {
                for try await piece in AIClient.shared.stream(system: system, messages: messages, maxTokens: 600) {
                    text += piece
                    let snapshot = text
                    await MainActor.run { self.streaming = snapshot }
                }
                let final = text.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    self.streaming = nil
                    guard !final.isEmpty else { self.error = AIError.emptyResponse.localizedDescription; return }
                    self.session.messages.append(ChatMessage(role: .assistant, text: final))
                    self.persist()
                    if autoSpeak { TTS.shared.speak(final) }
                }
            } catch {
                await MainActor.run {
                    self.streaming = nil
                    if !(error is CancellationError) { self.error = error.localizedDescription }
                }
            }
        }
    }

    func cancel() {
        replyTask?.cancel()
        streaming = nil
    }

    func retry() {
        requestReply()
    }

    private func correct(_ id: UUID, text: String, context: String) {
        correcting.insert(id)
        let level = session.level
        Task {
            let result = try? await AIClient.shared.json(Correction.self,
                                                         system: Prompts.correctionSystem(level: level),
                                                         prompt: Prompts.correctionPrompt(context: context, sentence: text),
                                                         maxTokens: 1200, fast: true)
            await MainActor.run {
                self.correcting.remove(id)
                guard let result, let i = self.session.messages.firstIndex(where: { $0.id == id }) else { return }
                self.session.messages[i].correction = result
                self.persist()
            }
        }
    }

    func translate(_ id: UUID) {
        guard let i = session.messages.firstIndex(where: { $0.id == id }) else { return }
        if session.messages[i].translation != nil {
            session.messages[i].translation = nil
            persist()
            return
        }
        let text = session.messages[i].text
        translating.insert(id)
        Task {
            let result = try? await AITasks.translate(text)
            await MainActor.run {
                self.translating.remove(id)
                guard let j = self.session.messages.firstIndex(where: { $0.id == id }) else { return }
                self.session.messages[j].translation = result ?? "（翻译失败）"
                self.persist()
            }
        }
    }

    func suggestions() async throws -> [Pair] {
        let last = session.messages.suffix(6).map { ($0.role == .user ? "学习者" : "对方") + "：" + $0.text }
        let prompt = "场景：\(scenario.setting)\n最近的对话：\n" + last.joined(separator: "\n") + "\n请给出学习者下一句可以说的话。"
        return try await AIClient.shared.json(Suggestions.self, system: Prompts.suggestSystem(level: session.level),
                                              prompt: prompt, maxTokens: 1200, fast: true).suggestions
    }

    private func persist() {
        ChatStore.shared.update(session)
    }
}

struct ChatView: View {
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ChatViewModel
    @StateObject private var recognizer = SpeechRecognizer()
    @AppStorage(Prefs.chatAutoSpeak) private var autoSpeak = true
    @AppStorage(Prefs.chatCorrections) private var corrections = true

    @State private var input = ""
    @State private var showGoal = true
    @State private var showSuggestions = false
    @FocusState private var inputFocused: Bool

    init(session: ChatSession) {
        _model = StateObject(wrappedValue: ChatViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !AIClient.shared.isConfigured {
                    AISetupPrompt(message: "AI 对话练习需要连接 AI。")
                    Spacer()
                } else {
                    messages
                    inputBar
                }
            }
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle(model.scenario.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { model.cancel(); dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Toggle("自动朗读回复", isOn: $autoSpeak)
                        Toggle("纠正我的句子", isOn: $corrections)
                        Button { showGoal.toggle() } label: { Label("场景说明", systemImage: "info.circle") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showSuggestions) {
                SuggestionSheet(model: model) { text in
                    input = text
                    showSuggestions = false
                }
                .presentationDetents([.medium])
            }
        }
        .onAppear { model.startIfNeeded() }
        .onDisappear { TTS.shared.stop() }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if showGoal {
                        goalBanner
                    }
                    ForEach(model.session.messages) { m in
                        if m.role == .assistant {
                            assistantBubble(m)
                        } else {
                            userBubble(m)
                        }
                    }
                    if let streaming = model.streaming {
                        HStack {
                            Text(streaming.isEmpty ? "…" : streaming)
                                .font(.spanish(18, weight: .regular))
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.vCard))
                            Spacer(minLength: 40)
                        }
                    }
                    if let error = model.error {
                        ErrorCard(message: error) { model.retry() }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.session.messages.count) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: model.streaming) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private var goalBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("场景", systemImage: "theatermasks").font(.caption.weight(.bold)).foregroundColor(.secondary)
            Text(model.scenario.setting).font(.subheadline)
            Text("对方：\(model.scenario.role)").font(.caption).foregroundColor(.secondary)
            Text("目标：\(model.scenario.goal)").font(.caption.weight(.semibold)).foregroundColor(.vRojo)
            Text("点任意西语单词可以查词；长按自己的话可以复制。")
                .font(.caption2).foregroundColor(.vMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func assistantBubble(_ m: ChatMessage) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                TappableText(text: m.text, font: .spanish(18, weight: .regular), lineSpacing: 4)
                if let t = m.translation {
                    Text(t).font(.subheadline).foregroundColor(.secondary)
                }
                HStack(spacing: 16) {
                    Button { TTS.shared.speak(m.text) } label: { Image(systemName: "speaker.wave.2") }
                    Button { TTS.shared.speak(m.text, slow: true) } label: { Image(systemName: "tortoise") }
                    Button { model.translate(m.id) } label: {
                        if model.translating.contains(m.id) { ProgressView().scaleEffect(0.7) }
                        else { Text(m.translation == nil ? "译" : "收起").font(.caption.weight(.bold)) }
                    }
                    Button {
                        progress.saveItem(es: m.text, zh: m.translation ?? "（对话中的句子）")
                        Haptics.success()
                    } label: { Image(systemName: "plus.rectangle.on.rectangle") }
                }
                .font(.subheadline)
                .foregroundColor(.vRojo)
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.vCard))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.vLine, lineWidth: 1))
            Spacer(minLength: 32)
        }
    }

    private func userBubble(_ m: ChatMessage) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                Spacer(minLength: 48)
                Text(m.text)
                    .font(.spanish(18, weight: .regular))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.vRojo))
                    .textSelection(.enabled)
            }
            if model.correcting.contains(m.id) {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("检查中…").font(.caption).foregroundColor(.secondary)
                }
            } else if let c = m.correction {
                correctionView(c)
            }
        }
    }

    private func correctionView(_ c: Correction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if c.ok {
                Label("没有错误", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.vOK)
            } else {
                Label("改正", systemImage: "pencil.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.vBad)
                Text(c.corrected).font(.spanish(16, weight: .medium))
                if let e = c.explanation, !e.isEmpty {
                    Text(e).font(.caption).foregroundColor(.secondary)
                }
            }
            if let n = c.natural, !n.isEmpty, n != c.corrected {
                Text("更地道：\(n)").font(.caption).foregroundColor(Color.unit("azul"))
            }
        }
        .padding(10)
        .frame(maxWidth: 300, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(c.ok ? Color.vOK.opacity(0.08) : Color.vBad.opacity(0.08)))
    }

    private var inputBar: some View {
        VStack(spacing: 6) {
            if recognizer.isRecording {
                Text(recognizer.transcript.isEmpty ? "正在听…（说西班牙语）" : recognizer.transcript)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let err = recognizer.errorMessage {
                Text(err).font(.caption).foregroundColor(.vBad)
            }
            HStack(spacing: 10) {
                Button { showSuggestions = true } label: {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 20))
                        .foregroundColor(.vOro)
                }
                .buttonStyle(.plain)
                .disabled(model.session.messages.isEmpty)

                TextField("用西班牙语回复…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.spanish(17, weight: .regular))
                    .textInputAutocapitalization(.sentences)
                    .focused($inputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.vCard))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.vLine, lineWidth: 1))

                if input.trimmingCharacters(in: .whitespaces).isEmpty {
                    MicButton(recognizer: recognizer, size: 40) { text in
                        if !text.isEmpty { input = text }
                    }
                } else {
                    Button {
                        let text = input
                        input = ""
                        model.send(text, corrections: corrections)
                        progress.countChatTurn()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(model.isBusy ? .vMuted : .vRojo)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isBusy)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.vBackground)
    }
}

private struct SuggestionSheet: View {
    @ObservedObject var model: ChatViewModel
    let onPick: (String) -> Void
    @State private var items: [Pair] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty && error == nil {
                    HStack { ProgressView(); Text("正在想…").foregroundColor(.secondary) }
                }
                if let error { Text(error).foregroundColor(.vBad) }
                ForEach(items, id: \.self) { p in
                    Button { onPick(p.es) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.es).font(.spanish(17, weight: .medium)).foregroundColor(.primary)
                            Text(p.zh).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("可以这样说")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                do { items = try await model.suggestions() } catch { self.error = error.localizedDescription }
            }
        }
    }
}
