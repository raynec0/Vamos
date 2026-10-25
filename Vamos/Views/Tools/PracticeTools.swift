import SwiftUI

// MARK: - Listening

struct ListeningView: View {
    @EnvironmentObject private var progress: ProgressStore
    @StateObject private var player = LinePlayer()
    @State private var level = ""
    @State private var topic = ""
    @State private var script: ListeningScript?
    @State private var loading = false
    @State private var error: String?
    @State private var showTranscript = false
    @State private var slow = false
    @State private var answers: [Int: Int] = [:]

    private let ideas = ["在面包店买东西", "在火车站改签", "朋友约看电影", "同事讨论项目进度", "邻居抱怨噪音", "在诊所预约", "在二手平台买东西", "计划去安达卢西亚旅行", "在健身房办卡", "家庭聚餐聊天"]

    private var lines: [LinePlayer.Line] {
        (script?.lines ?? []).map { LinePlayer.Line(text: $0.text, secondVoice: $0.speaker.uppercased().hasPrefix("B")) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !AIClient.shared.isConfigured {
                    AISetupPrompt(message: "听力材料由 AI 按你的水平生成。").card()
                } else {
                    controls
                    if loading { LoadingCard(text: "正在编写对话…") }
                    if let error { ErrorCard(message: error) { Task { await generate() } } }
                    if let s = script { scriptView(s) }
                }
            }
            .padding(16)
        }
        .background(Color.vBackground.ignoresSafeArea())
        .navigationTitle("听力")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if level.isEmpty { level = progress.learnerLevel } }
        .onDisappear { player.stop() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("级别", selection: $level) {
                ForEach(CourseStore.shared.levels.map(\.id), id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            TextField("场景（留空则随机）", text: $topic)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.vSunken))
            Button { Task { await generate() } } label: { Label("生成一段对话", systemImage: "sparkles") }
                .buttonStyle(ChunkyButtonStyle(color: Color.unit("morado"), enabled: !loading))
                .disabled(loading)
            if hasOneVoice {
                Text("提示：系统里只有一个西语声音时，两个角色会用同一个声音。可在「设置 → 辅助功能 → 朗读内容 → 声音」下载更多西班牙语声音。")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .card()
    }

    private var hasOneVoice: Bool { TTS.spanishVoices.count < 2 }

    private func scriptView(_ s: ListeningScript) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(s.title).font(.spanish(22, weight: .bold))
                if let sit = s.situation_zh { Text(sit).font(.subheadline).foregroundColor(.secondary) }
            }
            HStack(spacing: 10) {
                Button {
                    if player.isPlaying { player.stop() } else { player.play(lines, slow: slow) }
                } label: {
                    Label(player.isPlaying ? "停止" : "播放全部", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: Color.unit("morado")))
                Toggle("慢速", isOn: $slow).toggleStyle(.button).tint(.vOro)
            }
            Toggle("显示原文", isOn: $showTranscript)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(s.lines.enumerated()), id: \.offset) { i, line in
                    let isB = line.speaker.uppercased().hasPrefix("B")
                    HStack(alignment: .top, spacing: 10) {
                        Button { player.playOne(lines[i], index: i, slow: slow) } label: {
                            Image(systemName: player.currentIndex == i ? "speaker.wave.3.fill" : "play.circle")
                                .font(.title3)
                                .foregroundColor(isB ? Color.unit("azul") : .vRojo)
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.name ?? line.speaker).font(.caption.weight(.bold))
                                .foregroundColor(isB ? Color.unit("azul") : .vRojo)
                            if showTranscript {
                                TappableText(text: line.text, font: .spanish(17, weight: .regular), lineSpacing: 3)
                            } else {
                                Text(String(repeating: "▁ ", count: min(12, max(3, line.text.count / 8))))
                                    .font(.caption).foregroundColor(.vLine)
                            }
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(player.currentIndex == i ? Color.vOro.opacity(0.15) : Color.clear))
                }
            }
            .card()

            if let qs = s.questions, !qs.isEmpty {
                QuizBlock(questions: qs, answers: $answers)
            }
            if let v = s.vocab, !v.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("对话中的表达", systemImage: "text.quote").font(.headline)
                    ForEach(v, id: \.self) { p in
                        HStack {
                            Text(p.es).font(.spanish(16, weight: .semibold))
                            Text(p.zh).font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            Button { progress.saveItem(es: p.es, zh: p.zh); Haptics.success() } label: {
                                Image(systemName: progress.isSaved(es: p.es) ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundColor(progress.isSaved(es: p.es) ? .vOK : .vRojo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .card()
            }
        }
    }

    private func generate() async {
        player.stop()
        loading = true; error = nil; script = nil; answers = [:]; showTranscript = false
        let t = topic.trimmingCharacters(in: .whitespaces)
        let chosen = t.isEmpty ? (ideas.randomElement() ?? "日常对话") : t
        do {
            script = try await AIClient.shared.json(ListeningScript.self, system: Prompts.listeningSystem(level: level),
                                                    prompt: "场景：\(chosen)", maxTokens: 4000)
            progress.addXP(5)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - Pronunciation

struct PronunciationView: View {
    @EnvironmentObject private var progress: ProgressStore

    private struct Drill: Identifiable {
        var id: String { text }
        let text: String
        let zh: String
    }

    private let castilian: [(title: String, note: String, drills: [Drill])] = [
        ("咬舌音 [θ] 与 [s]", "西班牙本土区分 s 和 c/z：casa（房子）≠ caza（打猎）", [
            Drill(text: "casa / caza", zh: "房子 / 打猎"),
            Drill(text: "sien / cien", zh: "太阳穴 / 一百"),
            Drill(text: "Cecilia cocina cerezas.", zh: "塞西莉亚在煮樱桃。"),
            Drill(text: "Zaragoza y Cáceres", zh: "萨拉戈萨和卡塞雷斯")
        ]),
        ("喉音 j [x]", "舌根抬起摩擦，比拼音 h 更靠后", [
            Drill(text: "jamón, jirafa, joven", zh: "火腿、长颈鹿、年轻人"),
            Drill(text: "El jefe juega en el jardín.", zh: "老板在花园里玩。"),
            Drill(text: "gente, girasol, Jorge", zh: "人们、向日葵、豪尔赫")
        ]),
        ("单击 r 与颤音 rr", "pero（但是）≠ perro（狗）", [
            Drill(text: "pero / perro", zh: "但是 / 狗"),
            Drill(text: "caro / carro", zh: "贵的 / 车"),
            Drill(text: "El perro de Rosa corre rápido.", zh: "罗莎的狗跑得很快。")
        ]),
        ("软 d [ð] 与 ñ", "元音之间的 d 很轻；ñ 像 ni 合成一个音", [
            Drill(text: "nada, cansado, Madrid", zh: "没什么、累的、马德里"),
            Drill(text: "España, mañana, niño", zh: "西班牙、明天、孩子")
        ]),
        ("绕口令 Trabalenguas", "西班牙孩子从小练的经典绕口令", [
            Drill(text: "Tres tristes tigres tragaban trigo en un trigal.", zh: "三只悲伤的老虎在麦田里吞麦子。"),
            Drill(text: "El perro de San Roque no tiene rabo porque Ramón Ramírez se lo ha cortado.", zh: "圣罗克的狗没有尾巴，因为拉蒙·拉米雷斯把它剪掉了。"),
            Drill(text: "Pablito clavó un clavito. ¿Qué clavito clavó Pablito?", zh: "小巴勃罗钉了一颗小钉子。他钉了哪颗小钉子？"),
            Drill(text: "Cuando cuentes cuentos, cuenta cuántos cuentos cuentas.", zh: "你讲故事的时候，数数你讲了几个故事。")
        ])
    ]

    var body: some View {
        List {
            Section {
                Text("先听原音（可慢速），再按麦克风跟读。系统用西班牙语语音识别给每个词打分：绿色是听清的，红色是需要再练的。")
                    .font(.footnote).foregroundColor(.secondary)
            }
            ForEach(castilian.indices, id: \.self) { gi in
                let group = castilian[gi]
                Section {
                    ForEach(group.drills) { d in
                        NavigationLink {
                            SpeakingDrillView(text: d.text, zh: d.zh)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.text).font(.spanish(17, weight: .medium))
                                Text(d.zh).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(group.title)
                } footer: {
                    Text(group.note)
                }
            }
            let learned = progress.learnedItems.filter { $0.wordCount >= 2 && !$0.isPair }.prefix(30)
            if !learned.isEmpty {
                Section("来自已学内容") {
                    ForEach(Array(learned)) { item in
                        NavigationLink {
                            SpeakingDrillView(text: item.speakText, zh: item.zh)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.es).font(.spanish(17, weight: .medium))
                                Text(item.zh).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("发音练习")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Listen → record → per-word score.
struct SpeakingDrillView: View {
    let text: String
    let zh: String
    @EnvironmentObject private var progress: ProgressStore
    @StateObject private var recognizer = SpeechRecognizer()
    @State private var result: (words: [AnswerChecker.WordMatch], score: Double)?
    @State private var heard = ""
    @State private var best: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text(text).font(.spanish(26, weight: .bold)).multilineTextAlignment(.center)
                    Text(zh).font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 14) {
                        SpeakButton(text: text, size: 48)
                        SlowSpeakButton(text: text, size: 48)
                    }
                }
                .frame(maxWidth: .infinity)
                .card()

                MicButton(recognizer: recognizer, size: 76) { heardText in
                    heard = heardText
                    let r = AnswerChecker.pronunciation(target: text, heard: heardText)
                    result = r
                    if r.score > best {
                        if best < 0.85 && r.score >= 0.85 { progress.addXP(3) }
                        best = r.score
                    }
                    if r.score >= 0.85 { Haptics.success() }
                }
                Text(recognizer.isRecording ? (recognizer.transcript.isEmpty ? "正在听…说完再点一下" : recognizer.transcript)
                                            : "点麦克风开始跟读")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                if let e = recognizer.errorMessage {
                    Text(e).font(.caption).foregroundColor(.vBad).multilineTextAlignment(.center)
                }
                if let r = result {
                    PronunciationResultView(words: r.words, score: r.score, heard: heard)
                }
                Text("语音识别并不完美：数字可能被识别成阿拉伯数字，专有名词也可能识别错。重点看大部分词是否变绿。")
                    .font(.caption2).foregroundColor(.vMuted).multilineTextAlignment(.center)
            }
            .padding(16)
        }
        .background(Color.vBackground.ignoresSafeArea())
        .navigationTitle("跟读")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { recognizer.stop() }
    }
}

// MARK: - Writing

struct WritingView: View {
    @EnvironmentObject private var progress: ProgressStore
    @State private var topic: WritingTopic?
    @State private var text = ""
    @State private var feedback: WritingFeedback?
    @State private var loading = false
    @State private var loadingTopic = false
    @State private var error: String?
    @State private var tab = 0

    private var wordCount: Int { text.split(whereSeparator: { $0.isWhitespace }).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !AIClient.shared.isConfigured {
                    AISetupPrompt(message: "写作批改需要连接 AI。").card()
                } else {
                    topicCard
                    editor
                    if loading { LoadingCard(text: "老师正在批改…") }
                    if let error { ErrorCard(message: error) { Task { await check() } } }
                    if let f = feedback { feedbackView(f) }
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.vBackground.ignoresSafeArea())
        .navigationTitle("写作批改")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var topicCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("题目", systemImage: "lightbulb").font(.caption.weight(.bold)).foregroundColor(.secondary)
                Spacer()
                Button(loadingTopic ? "出题中…" : "换一个题目") { Task { await newTopic() } }
                    .font(.caption.weight(.semibold))
                    .disabled(loadingTopic)
            }
            if let t = topic {
                Text(t.topic_es).font(.spanish(17, weight: .semibold))
                Text(t.topic_zh).font(.caption).foregroundColor(.secondary)
            } else {
                Text("可以自由写，也可以让 AI 按你的水平（\(progress.learnerLevel)）出一个题目。")
                    .font(.subheadline).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var editor: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextEditor(text: $text)
                .font(.spanish(17, weight: .regular))
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.vCard))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vLine, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Escribe aquí…").font(.spanish(17, weight: .regular)).foregroundColor(.vMuted)
                            .padding(18).allowsHitTesting(false)
                    }
                }
            HStack {
                Text("\(wordCount) 词").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button { Task { await check() } } label: { Label("提交批改", systemImage: "checkmark.seal") }
                    .buttonStyle(ChunkyButtonStyle(color: Color.unit("tinto"), enabled: wordCount >= 5 && !loading))
                    .disabled(wordCount < 5 || loading)
                    .frame(maxWidth: 180)
            }
        }
    }

    private func feedbackView(_ f: WritingFeedback) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                if let s = f.score {
                    Text("\(s)").font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(s >= 80 ? .vOK : (s >= 60 ? .vOro : .vBad))
                    Text("分").foregroundColor(.secondary)
                }
                Spacer()
                if let l = f.level { Text("约 \(l) 水平").font(.headline) }
            }
            Text(f.summary).font(.subheadline).fixedSize(horizontal: false, vertical: true)

            Picker("", selection: $tab) {
                Text("错误").tag(0)
                Text("改正版").tag(1)
                Text("母语者版").tag(2)
            }
            .pickerStyle(.segmented)

            switch tab {
            case 0:
                if let errors = f.errors, !errors.isEmpty {
                    ForEach(errors, id: \.self) { e in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(e.original).strikethrough().foregroundColor(.vBad)
                                Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
                                Text(e.correction).foregroundColor(.vOK).fontWeight(.semibold)
                            }
                            .font(.spanish(16, weight: .regular))
                            Text((e.type.map { "【\($0)】" } ?? "") + e.explanation)
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.vSunken))
                    }
                } else {
                    Label("没有发现错误，¡Enhorabuena!", systemImage: "checkmark.circle.fill").foregroundColor(.vOK)
                }
            case 1:
                TappableText(text: f.corrected, font: .spanish(17, weight: .regular))
            default:
                TappableText(text: f.native ?? f.corrected, font: .spanish(17, weight: .regular))
                SpeakButton(text: f.native ?? f.corrected, size: 36)
            }

            if let v = f.vocab, !v.isEmpty {
                Divider()
                Label("值得学的表达", systemImage: "star").font(.subheadline.weight(.semibold))
                ForEach(v, id: \.self) { p in
                    HStack {
                        Text(p.es).font(.spanish(16, weight: .semibold))
                        Text(p.zh).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Button { progress.saveItem(es: p.es, zh: p.zh); Haptics.success() } label: {
                            Image(systemName: progress.isSaved(es: p.es) ? "checkmark.circle.fill" : "plus.circle")
                                .foregroundColor(progress.isSaved(es: p.es) ? .vOK : .vRojo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func newTopic() async {
        loadingTopic = true
        topic = try? await AIClient.shared.json(WritingTopic.self, system: Prompts.learner(level: progress.learnerLevel),
                                                prompt: Prompts.writingTopicPrompt(level: progress.learnerLevel),
                                                maxTokens: 800, fast: true)
        loadingTopic = false
    }

    private func check() async {
        loading = true; error = nil; feedback = nil
        var prompt = ""
        if let t = topic { prompt += "题目：\(t.topic_es)\n\n" }
        prompt += "学习者的作文：\n\(text)"
        do {
            feedback = try await AIClient.shared.json(WritingFeedback.self, system: Prompts.writingSystem(level: progress.learnerLevel),
                                                      prompt: prompt, maxTokens: 6000)
            tab = 0
            progress.countWriting()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - Resources

struct ResourcesView: View {
    private struct Resource: Identifiable {
        var id: String { url }
        let name: String
        let note: String
        let url: String
    }

    private let groups: [(title: String, items: [Resource])] = [
        ("词典与语言规范", [
            Resource(name: "RAE · DLE", note: "西班牙皇家语言学院的权威词典", url: "https://dle.rae.es"),
            Resource(name: "FundéuRAE", note: "西语用法疑难解答，新词怎么说", url: "https://www.fundeu.es"),
            Resource(name: "WordReference", note: "西英词典，论坛里有大量地道用法讨论", url: "https://www.wordreference.com/es/"),
            Resource(name: "Forvo", note: "真人发音，可以选西班牙口音", url: "https://forvo.com/languages/es/"),
            Resource(name: "Linguee", note: "看词语在真实双语文本里的用法", url: "https://www.linguee.es")
        ]),
        ("广播与电视（西班牙）", [
            Resource(name: "RTVE Play", note: "西班牙国家电视台，剧集、纪录片、新闻", url: "https://www.rtve.es/play/"),
            Resource(name: "Radio Nacional (RNE)", note: "国家电台直播和节目回放", url: "https://www.rtve.es/play/radio/"),
            Resource(name: "Cadena SER", note: "西班牙收听率最高的电台之一，tertulias 很多", url: "https://cadenaser.com")
        ]),
        ("播客（西班牙口音）", [
            Resource(name: "Hoy Hablamos", note: "每天一集，专为学习者做的西班牙西语播客", url: "https://www.hoyhablamos.com"),
            Resource(name: "Notes in Spanish", note: "马德里的真实对话，分初中高级", url: "https://www.notesinspanish.com")
        ]),
        ("考试与课程", [
            Resource(name: "Instituto Cervantes · DELE", note: "DELE 考试信息和样题", url: "https://examenes.cervantes.es/es/dele/que-es"),
            Resource(name: "Plan Curricular (PCIC)", note: "本应用 A2–C2 大纲的参考标准", url: "https://cvc.cervantes.es/ensenanza/biblioteca_ele/plan_curricular/")
        ])
    ]

    var body: some View {
        List {
            ForEach(groups.indices, id: \.self) { gi in
                let g = groups[gi]
                Section(g.title) {
                    ForEach(g.items) { r in
                        if let url = URL(string: r.url) {
                            Link(destination: url) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.name).font(.body.weight(.semibold)).foregroundColor(.primary)
                                    Text(r.note).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            Section {
                Text("想达到母语水平，课本之外最重要的是大量「可理解输入」：每天听半小时西班牙的广播或播客、看西班牙剧（先西语字幕，再无字幕），并且坚持和真人或 AI 对话。")
                    .font(.footnote).foregroundColor(.secondary)
            }
        }
        .navigationTitle("沉浸资源")
        .navigationBarTitleDisplayMode(.inline)
    }
}
