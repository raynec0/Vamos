import SwiftUI

/// The "探索" tab: every tool in one grid.
struct ToolsView: View {
    @EnvironmentObject private var progress: ProgressStore

    private struct Tool: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let needsAI: Bool
    }

    private let tools: [Tool] = [
        Tool(id: "lookup", title: "查词 · 翻译", subtitle: "词典、句子精读、中译西", icon: "character.book.closed.fill", color: .vRojo, needsAI: true),
        Tool(id: "conjugate", title: "动词变位", subtitle: "所有时态与语气", icon: "tablecells.fill", color: Color.unit("azul"), needsAI: true),
        Tool(id: "reading", title: "阅读", subtitle: "西班牙新闻 · 分级读物", icon: "newspaper.fill", color: Color.unit("verde"), needsAI: false),
        Tool(id: "listening", title: "听力", subtitle: "真实对话 + 理解题", icon: "headphones", color: Color.unit("morado"), needsAI: true),
        Tool(id: "speaking", title: "发音练习", subtitle: "跟读打分 · 绕口令", icon: "waveform", color: Color.unit("oro"), needsAI: false),
        Tool(id: "writing", title: "写作批改", subtitle: "DELE 考官式批改", icon: "square.and.pencil", color: Color.unit("tinto"), needsAI: true),
        Tool(id: "reference", title: "语法手册", subtitle: "发音、字母、变位表", icon: "text.book.closed.fill", color: .vMuted, needsAI: false),
        Tool(id: "resources", title: "沉浸资源", subtitle: "西班牙广播、播客、词典", icon: "globe.europe.africa.fill", color: Color.unit("azul"), needsAI: false)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(tools) { tool in
                        NavigationLink {
                            destination(tool.id)
                        } label: {
                            tile(tool)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)

                if !AIClient.shared.isConfigured {
                    Text("带 ✦ 的工具需要先在「我的 → AI 设置」里连接 AI。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
            }
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle("探索")
        }
    }

    private func tile(_ tool: Tool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: tool.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 11).fill(tool.color))
                Spacer()
                if tool.needsAI {
                    Text("✦").font(.caption).foregroundColor(.vOro)
                }
            }
            Text(tool.title).font(.headline).foregroundColor(.primary)
            Text(tool.subtitle).font(.caption).foregroundColor(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .card()
    }

    @ViewBuilder
    private func destination(_ id: String) -> some View {
        switch id {
        case "lookup": LookupToolView()
        case "conjugate": ConjugatorView()
        case "reading": ReadingHomeView()
        case "listening": ListeningView()
        case "speaking": PronunciationView()
        case "writing": WritingView()
        case "reference": ReferenceListView()
        default: ResourcesView()
        }
    }
}

// MARK: - Dictionary / sentence analysis / Chinese → Spanish

struct LookupToolView: View {
    @EnvironmentObject private var progress: ProgressStore
    @State private var query = ""
    @State private var entry: DictionaryEntry?
    @State private var analysis: SentenceAnalysis?
    @State private var error: String?
    @State private var loading = false
    @State private var history: [String] = UserDefaults.standard.stringArray(forKey: "lookup.history") ?? []
    @FocusState private var focused: Bool

    private var isChinese: Bool { query.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) } }
    private var isSingleWord: Bool { !isChinese && !query.trimmingCharacters(in: .whitespaces).contains(" ") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    TextField("输入西语单词、句子，或中文", text: $query, axis: .vertical)
                        .lineLimit(1...5)
                        .font(.spanish(18, weight: .regular))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focused)
                        .submitLabel(.search)
                        .onSubmit(search)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.vCard))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vLine, lineWidth: 1))
                    Button(action: search) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.vRojo))
                    }
                    .buttonStyle(.plain)
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || loading)
                }
                Text(modeHint).font(.caption).foregroundColor(.secondary)

                if !AIClient.shared.isConfigured {
                    AISetupPrompt(message: "查词和翻译需要连接 AI。").card()
                } else if loading {
                    LoadingCard(text: "正在查询…")
                } else if let error {
                    ErrorCard(message: error) { search() }
                } else if let entry {
                    DictionaryEntryView(entry: entry)
                    saveButton(es: entry.lemma ?? entry.word, zh: entry.meanings.map(\.zh).prefix(2).joined(separator: "；"),
                               note: entry.pos, pron: entry.ipa)
                } else if let analysis {
                    AnalysisView(analysis: analysis, source: query, chineseSource: isChinese)
                    saveButton(es: isChinese ? analysis.translation : query, zh: isChinese ? query : analysis.translation,
                               note: nil, pron: nil)
                } else if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近查过").font(.headline)
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(history, id: \.self) { h in
                                Button(h) { query = h; search() }
                                    .font(.subheadline)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Capsule().fill(Color.vCard))
                                    .overlay(Capsule().stroke(Color.vLine))
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.vBackground.ignoresSafeArea())
        .navigationTitle("查词 · 翻译")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if entry == nil && analysis == nil { focused = true } }
    }

    private var modeHint: String {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return "单个词 → 词典释义；句子 → 精读分析；中文 → 地道的西语说法" }
        if isChinese { return "模式：中译西" }
        return isSingleWord ? "模式：词典" : "模式：句子精读"
    }

    private func saveButton(es: String, zh: String, note: String?, pron: String?) -> some View {
        let saved = progress.isSaved(es: es)
        return Button(saved ? "已在复习卡片中" : "加入复习卡片") {
            progress.saveItem(es: es, zh: zh, note: note, pron: pron)
            Haptics.success()
        }
        .buttonStyle(ChunkyButtonStyle(color: .vOK, enabled: !saved))
        .disabled(saved)
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, AIClient.shared.isConfigured else { return }
        focused = false
        entry = nil; analysis = nil; error = nil; loading = true
        history.removeAll { $0 == q }
        history.insert(q, at: 0)
        history = Array(history.prefix(20))
        UserDefaults.standard.set(history, forKey: "lookup.history")
        let level = progress.learnerLevel
        let single = isSingleWord
        Task {
            do {
                if single {
                    let r = try await AITasks.lookup(q, level: level)
                    await MainActor.run { entry = r; loading = false }
                } else {
                    let r = try await AITasks.analyze(q, level: level)
                    await MainActor.run { analysis = r; loading = false }
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; loading = false }
            }
        }
    }
}

struct AnalysisView: View {
    let analysis: SentenceAnalysis
    let source: String
    let chineseSource: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label(chineseSource ? "西语说法" : "翻译", systemImage: "text.bubble").font(.caption.weight(.bold)).foregroundColor(.secondary)
                if chineseSource {
                    HStack(alignment: .top) {
                        TappableText(text: analysis.translation, font: .spanish(22, weight: .semibold))
                        Spacer()
                        SpeakButton(text: analysis.translation, size: 36)
                    }
                } else {
                    Text(analysis.translation).font(.title3.weight(.semibold))
                    HStack {
                        SpeakButton(text: source, size: 32)
                        SlowSpeakButton(text: source, size: 32)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            if let chunks = analysis.breakdown, !chunks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("逐段解析", systemImage: "list.bullet.indent").font(.caption.weight(.bold)).foregroundColor(.secondary)
                    ForEach(chunks, id: \.self) { c in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(c.es).font(.spanish(17, weight: .semibold))
                                Text(c.zh).font(.subheadline).foregroundColor(.secondary)
                            }
                            if let n = c.note, !n.isEmpty { Text(n).font(.caption).foregroundColor(.secondary) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            if let g = analysis.grammar, !g.isEmpty {
                bulletCard("语法要点", g, icon: "book.closed")
            }
            if let n = analysis.natural, !n.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("其它说法", systemImage: "arrow.triangle.swap").font(.caption.weight(.bold)).foregroundColor(.secondary)
                    ForEach(n, id: \.self) { s in
                        HStack(alignment: .top) {
                            Button { TTS.shared.speak(s) } label: { Image(systemName: "speaker.wave.2") }
                                .buttonStyle(.plain).foregroundColor(.vRojo)
                            Text(s).font(.spanish(16, weight: .regular))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            if let r = analysis.register, !r.isEmpty {
                Label(r, systemImage: "person.2.wave.2").font(.footnote).foregroundColor(.secondary)
            }
        }
    }

    private func bulletCard(_ title: String, _ lines: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.caption.weight(.bold)).foregroundColor(.secondary)
            ForEach(lines, id: \.self) { l in
                Text("• " + l).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Conjugator

struct ConjugatorView: View {
    @State private var verb = ""
    @State private var result: Conjugation?
    @State private var error: String?
    @State private var loading = false
    @FocusState private var focused: Bool

    private let persons = ["yo", "tú", "él / ella / usted", "nosotros", "vosotros", "ellos / ustedes"]
    private let quick = ["ser", "estar", "ir", "tener", "hacer", "poder", "decir", "querer", "venir", "poner", "saber", "salir"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    TextField("输入动词原形，如 hablar", text: $verb)
                        .font(.spanish(18, weight: .regular))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focused)
                        .submitLabel(.search)
                        .onSubmit { run(verb) }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.vCard))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vLine, lineWidth: 1))
                    Button { run(verb) } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.unit("azul")))
                    }
                    .buttonStyle(.plain)
                }
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(quick, id: \.self) { v in
                        Button(v) { verb = v; run(v) }
                            .font(.spanish(15, weight: .medium))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.vCard))
                            .overlay(Capsule().stroke(Color.vLine))
                            .buttonStyle(.plain)
                    }
                }

                if !AIClient.shared.isConfigured {
                    AISetupPrompt(message: "变位表需要连接 AI 生成（之后会缓存，离线可看）。").card()
                } else if loading {
                    LoadingCard(text: "正在生成变位表…")
                } else if let error {
                    ErrorCard(message: error) { run(verb) }
                } else if let r = result {
                    header(r)
                    ForEach(r.tenses, id: \.self) { t in tenseCard(t) }
                }
            }
            .padding(16)
        }
        .background(Color.vBackground.ignoresSafeArea())
        .navigationTitle("动词变位")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ r: Conjugation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(r.infinitive).font(.spanish(30, weight: .bold))
                SpeakButton(text: r.infinitive, size: 34)
                Spacer()
                if r.irregular == true {
                    Text("不规则").font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.vBad.opacity(0.12)))
                        .foregroundColor(.vBad)
                }
            }
            if let m = r.meaning { Text(m).font(.title3).foregroundColor(.secondary) }
            HStack(spacing: 16) {
                if let g = r.gerund { Text("副动词 ").foregroundColor(.secondary) + Text(g).font(.spanish(16)) }
                if let p = r.participle { Text("分词 ").foregroundColor(.secondary) + Text(p).font(.spanish(16)) }
            }
            .font(.subheadline)
            if let n = r.notes, !n.isEmpty {
                Text(n).font(.footnote).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func tenseCard(_ t: Conjugation.Tense) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t.name).font(.headline)
                Spacer()
                if let mood = t.mood { Text(mood).font(.caption).foregroundColor(.secondary) }
            }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                ForEach(Array(t.forms.prefix(6).enumerated()), id: \.offset) { i, form in
                    GridRow {
                        Text(i < persons.count ? persons[i] : "").font(.caption).foregroundColor(.secondary)
                        Button { if form != "—" { TTS.shared.speak(form) } } label: {
                            Text(form).font(.spanish(17, weight: .medium)).foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func run(_ v: String) {
        let clean = v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty, AIClient.shared.isConfigured else { return }
        focused = false
        loading = true; error = nil; result = nil
        Task {
            do {
                let r = try await AITasks.conjugate(clean)
                await MainActor.run { result = r; loading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; loading = false }
            }
        }
    }
}
