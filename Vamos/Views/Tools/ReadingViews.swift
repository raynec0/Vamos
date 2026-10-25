import SwiftUI
import SafariServices

struct ReadingHomeView: View {
    @State private var mode = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                Text("西班牙新闻").tag(0)
                Text("AI 分级读物").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            if mode == 0 { NewsListView() } else { GradedReaderView() }
        }
        .background(Color.vBackground.ignoresSafeArea())
        .navigationTitle("阅读")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - News

struct NewsListView: View {
    @State private var feeds = NewsService.feeds
    @State private var feed: NewsFeed = NewsService.feeds[0]
    @State private var articles: [NewsArticle] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showAddFeed = false
    @State private var newFeedName = ""
    @State private var newFeedURL = ""

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(feeds) { f in
                            Button(f.name) { feed = f; Task { await load() } }
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(f == feed ? Color.vRojo : Color.vCard))
                                .foregroundColor(f == feed ? .white : .primary)
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if !NewsFeed.defaults.contains(f) {
                                        Button("删除这个源", role: .destructive) {
                                            NewsService.removeFeed(f)
                                            feeds = NewsService.feeds
                                        }
                                    }
                                }
                        }
                        Button { showAddFeed = true } label: { Image(systemName: "plus.circle") }
                            .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            if loading {
                HStack { ProgressView(); Text("正在加载…").foregroundColor(.secondary) }
            } else if let error {
                Text(error).foregroundColor(.vBad).font(.subheadline)
            }
            ForEach(articles) { a in
                NavigationLink {
                    ArticleView(article: a)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.title).font(.spanish(17, weight: .semibold)).lineLimit(3)
                        if !a.summary.isEmpty {
                            Text(a.summary).font(.caption).foregroundColor(.secondary).lineLimit(2)
                        }
                        if let d = a.date {
                            Text(d, style: .relative).font(.caption2).foregroundColor(.vMuted)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await load() }
        .task { if articles.isEmpty { await load() } }
        .alert("添加 RSS 源", isPresented: $showAddFeed) {
            TextField("名称（如 ABC）", text: $newFeedName)
            TextField("RSS 地址 https://…", text: $newFeedURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            Button("添加") {
                let n = newFeedName.trimmingCharacters(in: .whitespaces)
                let u = newFeedURL.trimmingCharacters(in: .whitespaces)
                if !u.isEmpty, URL(string: u) != nil {
                    NewsService.addFeed(name: n.isEmpty ? u : n, url: u)
                    feeds = NewsService.feeds
                }
                newFeedName = ""
                newFeedURL = ""
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("任何西语 RSS 地址都可以，比如 ABC、La Vanguardia、RTVE。")
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let list = try await NewsService.fetch(feed)
            articles = list
            if list.isEmpty { error = "这个源暂时没有内容（可能需要代理或换一个源）。" }
        } catch {
            self.error = "加载失败：\(error.localizedDescription)。在国内访问西班牙媒体可能需要代理。"
            articles = []
        }
        loading = false
    }
}

struct ArticleView: View {
    let article: NewsArticle
    @EnvironmentObject private var progress: ProgressStore
    @StateObject private var player = LinePlayer()

    @State private var body_: String?
    @State private var loadingBody = true
    @State private var explanation: NewsExplanation?
    @State private var explaining = false
    @State private var explainError: String?
    @State private var showSafari = false

    private var text: String { body_ ?? article.summary }
    private var paragraphs: [String] {
        text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.source).font(.caption.weight(.bold)).foregroundColor(.vRojo)
                TappableText(text: article.title, font: .spanish(24, weight: .bold), lineSpacing: 2)

                HStack(spacing: 10) {
                    Button {
                        if player.isPlaying { player.stop() }
                        else { player.play(([article.title] + paragraphs).map { LinePlayer.Line(text: $0, secondVoice: false) }) }
                    } label: {
                        Label(player.isPlaying ? "停止" : "朗读全文", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Color.unit("verde")))
                    Button { showSafari = true } label: { Label("原网页", systemImage: "safari") }
                        .buttonStyle(ChunkyButtonStyle(color: .vCard, foreground: .primary))
                        .disabled(URL(string: article.link) == nil)
                }

                if loadingBody {
                    LoadingCard(text: "正在获取正文…")
                } else if body_ == nil {
                    Text("没能自动提取正文，下面是摘要。完整内容可以点「原网页」查看。")
                        .font(.caption).foregroundColor(.secondary)
                }

                ForEach(Array(paragraphs.enumerated()), id: \.offset) { i, p in
                    TappableText(text: p, font: .spanish(18, weight: .regular))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(player.currentIndex == i + 1 ? Color.vOro.opacity(0.18) : Color.clear))
                }

                Text("点任意单词查词典。").font(.caption).foregroundColor(.vMuted)

                if AIClient.shared.isConfigured {
                    if let e = explanation {
                        explanationView(e)
                    } else if explaining {
                        LoadingCard(text: "AI 正在精读这篇文章…")
                    } else {
                        if let explainError { Text(explainError).font(.caption).foregroundColor(.vBad) }
                        Button { Task { await explain() } } label: {
                            Label("AI 精读：摘要 + 生词 + 背景", systemImage: "sparkles")
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Color.unit("morado")))
                    }
                }
            }
            .padding(16)
        }
        .background(Color.vBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if body_ == nil, !article.link.isEmpty {
                body_ = await NewsService.fetchArticleText(article.link)
            }
            loadingBody = false
        }
        .onDisappear { player.stop() }
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: article.link) { SafariView(url: url).ignoresSafeArea() }
        }
    }

    private func explanationView(_ e: NewsExplanation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI 精读", systemImage: "sparkles").font(.headline)
                Spacer()
                if let d = e.difficulty { Text("难度 \(d)").font(.caption.weight(.bold)).foregroundColor(.secondary) }
            }
            Text(e.summary_zh).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            if let c = e.context, !c.isEmpty {
                Text("背景：\(c)").font(.footnote).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let vocab = e.vocab, !vocab.isEmpty {
                Divider()
                ForEach(vocab, id: \.self) { p in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.es).font(.spanish(16, weight: .semibold))
                            Text(p.zh + ((p.note ?? "").isEmpty ? "" : "（\(p.note ?? "")）"))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            progress.saveItem(es: p.es, zh: p.zh, note: p.note)
                            Haptics.success()
                        } label: {
                            Image(systemName: progress.isSaved(es: p.es) ? "checkmark.circle.fill" : "plus.circle")
                                .foregroundColor(progress.isSaved(es: p.es) ? .vOK : .vRojo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let ex = e.expressions, !ex.isEmpty {
                Divider()
                ForEach(ex, id: \.self) { Text("• " + $0).font(.footnote) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func explain() async {
        explaining = true
        explainError = nil
        let content = "标题：\(article.title)\n\n" + String(text.prefix(6000))
        do {
            explanation = try await AIClient.shared.json(NewsExplanation.self,
                                                         system: Prompts.newsExplainSystem(level: progress.learnerLevel),
                                                         prompt: content, maxTokens: 3000)
            progress.addXP(5)
        } catch {
            explainError = error.localizedDescription
        }
        explaining = false
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        return SFSafariViewController(url: url, configuration: config)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

// MARK: - AI graded reader

struct GradedReaderView: View {
    @EnvironmentObject private var progress: ProgressStore
    @StateObject private var player = LinePlayer()
    @State private var topic = ""
    @State private var level = ""
    @State private var reader: GradedReader?
    @State private var loading = false
    @State private var error: String?
    @State private var answers: [Int: Int] = [:]

    private let ideas = ["西班牙的午睡文化", "马德里的一天", "圣地亚哥朝圣之路", "西班牙人怎么过圣诞", "弗拉门戈的起源", "高迪和巴塞罗那", "西班牙的足球", "地中海饮食", "西班牙年轻人的工作", "加那利群岛"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !AIClient.shared.isConfigured {
                    AISetupPrompt(message: "分级读物由 AI 按你的水平生成。").card()
                } else {
                    controls
                    if loading { LoadingCard(text: "正在为你写一篇文章…") }
                    if let error { ErrorCard(message: error) { Task { await generate() } } }
                    if let r = reader { readerView(r) }
                }
            }
            .padding(16)
        }
        .onAppear { if level.isEmpty { level = progress.learnerLevel } }
        .onDisappear { player.stop() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("级别").font(.subheadline)
                Picker("级别", selection: $level) {
                    ForEach(CourseStore.shared.levels.map(\.id), id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            TextField("话题（留空则随机）", text: $topic)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.vCard))
            Button { Task { await generate() } } label: { Label("生成文章", systemImage: "sparkles") }
                .buttonStyle(ChunkyButtonStyle(color: Color.unit("verde"), enabled: !loading))
                .disabled(loading)
        }
        .card()
    }

    private func readerView(_ r: GradedReader) -> some View {
        let paragraphs = r.text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(r.title).font(.spanish(24, weight: .bold))
                Spacer()
                Button {
                    if player.isPlaying { player.stop() }
                    else { player.play(paragraphs.map { LinePlayer.Line(text: $0, secondVoice: false) }) }
                } label: {
                    Image(systemName: player.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34)).foregroundColor(.vRojo)
                }
                .buttonStyle(.plain)
            }
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { i, p in
                TappableText(text: p)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(player.currentIndex == i ? Color.vOro.opacity(0.18) : Color.clear))
            }
            if let g = r.glossary, !g.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("生词表", systemImage: "list.bullet").font(.headline)
                    ForEach(g, id: \.self) { p in
                        HStack {
                            Text(p.es).font(.spanish(16, weight: .semibold))
                            Text(p.zh).font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            Button {
                                progress.saveItem(es: p.es, zh: p.zh)
                                Haptics.success()
                            } label: {
                                Image(systemName: progress.isSaved(es: p.es) ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundColor(progress.isSaved(es: p.es) ? .vOK : .vRojo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .card()
            }
            if let qs = r.questions, !qs.isEmpty {
                QuizBlock(questions: qs, answers: $answers)
            }
        }
    }

    private func generate() async {
        loading = true; error = nil; reader = nil; answers = [:]
        let t = topic.trimmingCharacters(in: .whitespaces)
        let chosen = t.isEmpty ? (ideas.randomElement() ?? "西班牙") : t
        do {
            reader = try await AIClient.shared.json(GradedReader.self, system: Prompts.readerSystem(level: level),
                                                    prompt: "话题：\(chosen)", maxTokens: 4000)
            progress.addXP(5)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

/// Multiple-choice comprehension questions.
struct QuizBlock: View {
    let questions: [ComprehensionQuestion]
    @Binding var answers: [Int: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("理解题", systemImage: "questionmark.circle").font(.headline)
            ForEach(Array(questions.enumerated()), id: \.offset) { qi, q in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(qi + 1). \(q.q)").font(.subheadline.weight(.semibold))
                    ForEach(Array(q.options.enumerated()), id: \.offset) { oi, option in
                        let picked = answers[qi]
                        let isAnswer = oi == q.answer
                        Button {
                            if answers[qi] == nil {
                                answers[qi] = oi
                                if isAnswer { Haptics.success() } else { Haptics.error() }
                            }
                        } label: {
                            HStack {
                                Text(option).font(.subheadline).foregroundColor(.primary).multilineTextAlignment(.leading)
                                Spacer()
                                if picked != nil && isAnswer { Image(systemName: "checkmark.circle.fill").foregroundColor(.vOK) }
                                if picked == oi && !isAnswer { Image(systemName: "xmark.circle.fill").foregroundColor(.vBad) }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.vSunken))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            let done = answers.count
            if done == questions.count && done > 0 {
                let right = questions.indices.filter { answers[$0] == questions[$0].answer }.count
                Text("答对 \(right) / \(questions.count)").font(.headline).foregroundColor(right == questions.count ? .vOK : .vOro)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
