import SwiftUI

// MARK: - AI settings

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config = AIConfig.load()
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false
    @State private var showKey = false

    private var preset: AIPreset? { AIPreset.all.first { $0.id == config.presetId } }

    var body: some View {
        Form {
            Section {
                Picker("服务", selection: Binding(
                    get: { config.presetId },
                    set: { id in
                        if let p = AIPreset.all.first(where: { $0.id == id }) { config.apply(p) }
                        testResult = nil
                    })) {
                    ForEach(AIPreset.all) { p in Text(p.name).tag(p.id) }
                }
                if let p = preset {
                    Text(p.note).font(.caption).foregroundColor(.secondary)
                    if let url = URL(string: p.keyURL), !p.keyURL.isEmpty {
                        Link("获取 API Key →", destination: url).font(.subheadline)
                    }
                }
            } header: {
                Text("AI 服务")
            } footer: {
                Text("AI 用来生成 A2–C2 课程、对话陪练、批改、查词等。费用由你的 API 账户承担；生成过的课程会缓存在手机上，不会重复收费。")
            }

            Section("API Key") {
                HStack {
                    if showKey {
                        TextField("粘贴 API Key", text: $config.apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("粘贴 API Key", text: $config.apiKey)
                    }
                    Button { showKey.toggle() } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }

            Section {
                Picker("接口格式", selection: $config.provider) {
                    ForEach(AIProvider.allCases) { Text($0.title).tag($0) }
                }
                TextField("接口地址", text: $config.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                TextField("主模型", text: $config.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                TextField("快速模型（可留空）", text: $config.fastModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            } header: {
                Text("高级")
            } footer: {
                Text("主模型用于生成课程、对话和批改；快速模型用于查词、纠错、翻译等小任务。用中转服务或代理时，把接口地址改成对应的地址即可。")
            }

            Section {
                Button {
                    Task { await test() }
                } label: {
                    HStack {
                        Text(testing ? "测试中…" : "保存并测试连接")
                        Spacer()
                        if testing { ProgressView() }
                    }
                }
                .disabled(testing || config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                if let r = testResult {
                    Label(r, systemImage: testOK ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundColor(testOK ? .vOK : .vBad)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("AI 设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    config.save()
                    dismiss()
                }
            }
        }
    }

    private func test() async {
        config.save()
        testing = true
        testResult = nil
        do {
            let reply = try await AIClient.shared.complete(
                system: "Responde solo con una frase corta en español de España.",
                messages: [AIMessage(role: .user, content: "Saluda a un estudiante chino que aprende español.")],
                maxTokens: 300, fast: true)
            testOK = true
            testResult = "连接成功：\(reply.prefix(80))"
        } catch {
            testOK = false
            testResult = error.localizedDescription
        }
        testing = false
    }
}

// MARK: - Placement test

struct PlacementQuestion: Decodable {
    let level: String
    let q: String
    let options: [String]
    let answer: Int
}

private struct PlacementFile: Decodable {
    let questions: [PlacementQuestion]
}

struct PlacementTestView: View {
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss

    private let byLevel: [(level: String, questions: [PlacementQuestion])]

    @State private var levelIndex = 0
    @State private var questionIndex = 0
    @State private var correctInLevel = 0
    @State private var picked: Int?
    @State private var shuffled: [String] = []
    @State private var finishedLevel: Int?
    @State private var started = false

    init() {
        var groups: [(level: String, questions: [PlacementQuestion])] = []
        if let url = Bundle.main.url(forResource: "placement", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(PlacementFile.self, from: data) {
            for level in CourseStore.shared.levels.map(\.id) {
                let qs = file.questions.filter { $0.level == level }
                if !qs.isEmpty { groups.append((level: level, questions: qs)) }
            }
        }
        byLevel = groups
    }

    private var current: PlacementQuestion? {
        guard levelIndex < byLevel.count, questionIndex < byLevel[levelIndex].questions.count else { return nil }
        return byLevel[levelIndex].questions[questionIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let result = finishedLevel {
                    resultView(result)
                } else if !started {
                    intro
                } else if let q = current {
                    questionView(q)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle("分级测试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }

    private var intro: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 54)).foregroundColor(.vRojo)
            Text("测一测你的西语水平").font(.title2.weight(.bold))
            Text("从 A1 开始，每个级别 6 道题，答对 4 道以上就进入下一级，答不到就停在那里。大约 3–5 分钟。\n测试结果会解锁对应级别之前的全部课程。")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button("开始") {
                started = true
                prepare()
            }
            .buttonStyle(ChunkyButtonStyle())
        }
        .padding(.top, 40)
    }

    private func questionView(_ q: PlacementQuestion) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(byLevel[levelIndex].level)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.unit(CourseStore.shared.level(byLevel[levelIndex].level)?.color ?? "rojo")))
                Spacer()
                Text("\(questionIndex + 1) / \(byLevel[levelIndex].questions.count)")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Text(q.q).font(.spanish(24, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            ForEach(shuffled.indices, id: \.self) { i in
                Button {
                    guard picked == nil else { return }
                    picked = i
                    let right = shuffled[i] == q.options[q.answer]
                    if right { correctInLevel += 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { next() }
                } label: {
                    Text(shuffled[i])
                        .font(.spanish(19, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(OptionButtonStyle(border: picked == i ? .vRojo : .vLine,
                                               fill: picked == i ? Color.vRojo.opacity(0.08) : .vCard))
            }
            Text("不确定就选最像的，别查资料哦。").font(.caption).foregroundColor(.vMuted)
        }
    }

    private func resultView(_ index: Int) -> some View {
        let levels = CourseStore.shared.levels
        let level = levels[min(index, levels.count - 1)]
        return VStack(spacing: 16) {
            Text(level.id)
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundColor(Color.unit(level.color))
            Text("建议从 \(level.id)「\(level.title)」开始").font(.title3.weight(.bold))
            Text(level.summary).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Text(index > 0 ? "已解锁 \(levels.prefix(index + 1).map(\.id).joined(separator: "、")) 的课程。之前级别的内容随时可以回去复习。" : "从第一课开始稳扎稳打吧！")
                .font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button("开始学习") {
                progress.setPlacement(index)
                UserDefaults.standard.set(level.id, forKey: Prefs.selectedLevel)
                dismiss()
            }
            .buttonStyle(ChunkyButtonStyle())
        }
        .padding(.top, 30)
    }

    private func prepare() {
        picked = nil
        if let q = current { shuffled = q.options.shuffled() }
    }

    private func next() {
        let total = byLevel[levelIndex].questions.count
        if questionIndex + 1 < total {
            questionIndex += 1
            prepare()
            return
        }
        // End of a level: pass with at least 2/3 correct.
        let passed = correctInLevel * 3 >= total * 2
        if passed && levelIndex + 1 < byLevel.count {
            levelIndex += 1
            questionIndex = 0
            correctInLevel = 0
            prepare()
        } else {
            let levelIds = CourseStore.shared.levels.map(\.id)
            let reached = levelIds.firstIndex(of: byLevel[levelIndex].level) ?? 0
            // Passed the last level → C2; otherwise start at the level that was failed.
            finishedLevel = reached
            if passed { finishedLevel = reached }
            Haptics.success()
        }
    }
}
