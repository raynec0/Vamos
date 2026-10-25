import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var progress: ProgressStore

    @AppStorage(Prefs.dailyGoal) private var dailyGoal = 30
    @AppStorage(Prefs.speechRate) private var speechRate = Prefs.defaultSpeechRate
    @AppStorage(Prefs.autoPlay) private var autoPlay = true
    @AppStorage(Prefs.unlockAll) private var unlockAll = false
    @AppStorage(Prefs.reviewDirection) private var reviewDirection = ReviewDirection.esToZh.rawValue
    @AppStorage(Prefs.reminderOn) private var reminderOn = false
    @AppStorage(Prefs.reminderHour) private var reminderHour = 20
    @AppStorage(Prefs.reminderMinute) private var reminderMinute = 0
    @AppStorage(Prefs.learnerBackground) private var background = ""
    @AppStorage(Prefs.speakingDrills) private var speakingDrills = true
    @ObservedObject private var repository = LessonRepository.shared

    @State private var confirmReset = false
    @State private var reminderDenied = false
    @State private var showPlacement = false
    @State private var showAISettings = false
    @State private var confirmClearAI = false
    @State private var aiReady = AIClient.shared.isConfigured

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderHour = parts.hour ?? 20
            reminderMinute = parts.minute ?? 0
            if reminderOn { scheduleReminder() }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statsGrid
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("最近 7 天") {
                    weekChart
                        .padding(.vertical, 8)
                }

                Section {
                    Button { showAISettings = true } label: {
                        HStack {
                            Label("AI 设置", systemImage: "sparkles")
                            Spacer()
                            Text(aiReady ? "已连接" : "未设置")
                                .foregroundColor(aiReady ? .vOK : .vBad)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("个人背景（可选）")
                        TextField("例如：工程师，喜欢旅行和美食，想去西班牙工作", text: $background, axis: .vertical)
                            .lineLimit(1...3)
                            .font(.subheadline)
                    }
                } header: {
                    Text("AI")
                } footer: {
                    Text("AI 生成课文、对话和例句时会尽量贴近你的背景。")
                }

                Section("水平") {
                    HStack {
                        Text("当前水平")
                        Spacer()
                        Text(progress.learnerLevel).font(.headline).foregroundColor(.vRojo)
                    }
                    Button { showPlacement = true } label: { Label("做分级测试", systemImage: "chart.bar.doc.horizontal") }
                    NavigationLink {
                        SavedWordsView()
                    } label: {
                        HStack {
                            Label("我收藏的词句", systemImage: "bookmark")
                            Spacer()
                            Text("\(progress.savedItems.count)").foregroundColor(.secondary)
                        }
                    }
                }

                Section("学习目标") {
                    Picker("每日目标", selection: $dailyGoal) {
                        Text("轻松 · 10 XP").tag(10)
                        Text("普通 · 20 XP").tag(20)
                        Text("认真 · 30 XP").tag(30)
                        Text("拼命 · 50 XP").tag(50)
                    }
                    Toggle("解锁全部课程", isOn: $unlockAll)
                    Toggle("课后口语题（需要麦克风）", isOn: $speakingDrills)
                }

                Section {
                    Toggle("自动朗读", isOn: $autoPlay)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("朗读语速")
                            Spacer()
                            Text(rateLabel).foregroundColor(.secondary)
                        }
                        Slider(value: $speechRate, in: 0.30...0.55, step: 0.01)
                            .tint(.vRojo)
                    }
                    Button {
                        TTS.shared.speak("Hola, ¿qué tal? Me llamo Lucía y soy de Madrid.")
                    } label: {
                        Label("试听：\(TTS.shared.voiceName)", systemImage: "speaker.wave.2")
                    }
                } header: {
                    Text("发音")
                } footer: {
                    Text("使用 iOS 自带的西班牙（es-ES）语音。到「设置 → 辅助功能 → 朗读内容 → 声音 → 西班牙语」下载「增强」或「高级」语音，音质会好很多。")
                }

                Section("复习") {
                    Picker("卡片方向", selection: $reviewDirection) {
                        ForEach(ReviewDirection.allCases) { d in
                            Text(d.title).tag(d.rawValue)
                        }
                    }
                }

                Section {
                    Toggle("每日提醒", isOn: $reminderOn)
                        .onChange(of: reminderOn) { on in
                            if on { scheduleReminder() } else { Reminder.cancel() }
                        }
                    if reminderOn {
                        DatePicker("提醒时间", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("提醒")
                } footer: {
                    if reminderDenied {
                        Text("通知权限被拒绝，请到系统设置里为 Vamos 打开通知。")
                            .foregroundColor(.vBad)
                    }
                }

                Section {
                    HStack {
                        Text("已生成的 AI 课程")
                        Spacer()
                        Text("\(repository.generatedCount) 节").foregroundColor(.secondary)
                    }
                    Button("清除 AI 缓存（课程会重新生成）", role: .destructive) { confirmClearAI = true }
                    Button("重置全部学习进度", role: .destructive) { confirmReset = true }
                } header: {
                    Text("数据")
                } footer: {
                    Text("Vamos 2.0 · 西班牙本土西语（Castellano）· A1–C2")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle("我的")
            .sheet(isPresented: $showPlacement) { PlacementTestView().environmentObject(progress) }
            .sheet(isPresented: $showAISettings, onDismiss: { aiReady = AIClient.shared.isConfigured }) {
                NavigationStack { AISettingsView() }
            }
            .confirmationDialog("删除所有 AI 生成的课程、查词和变位缓存？学习记录不受影响。",
                                isPresented: $confirmClearAI, titleVisibility: .visible) {
                Button("清除", role: .destructive) {
                    repository.discardAll()
                    AICache.clear()
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("所有课程记录、复习卡片和经验都会清空，确定吗？",
                                isPresented: $confirmReset, titleVisibility: .visible) {
                Button("重置", role: .destructive) { progress.resetAll() }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var rateLabel: String {
        switch speechRate {
        case ..<0.36: return "很慢"
        case ..<0.42: return "慢"
        case ..<0.48: return "适中"
        default: return "正常"
        }
    }

    private var statsGrid: some View {
        let total = CourseStore.shared.lessonsInOrder.count
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tile("flame.fill", .orange, "\(progress.streak) 天", "连续学习")
            tile("bolt.fill", .vOro, "\(progress.data.xp)", "总经验")
            tile("checkmark.seal.fill", .vOK, "\(progress.completedCount)/\(total)", "完成课程")
            tile("rectangle.stack.fill", Color.unit("azul"), "\(progress.data.cards.count)", "已学词句")
            tile("bubble.left.and.bubble.right.fill", Color.unit("morado"), "\(progress.data.chatTurns)", "对话句数")
            tile("square.and.pencil", Color.unit("tinto"), "\(progress.data.writingsChecked)", "批改作文")
        }
    }

    private func tile(_ icon: String, _ color: Color, _ value: String, _ label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(.title3, design: .rounded).weight(.bold))
                Text(label).font(.caption).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private var weekChart: some View {
        let week = progress.lastWeek
        let peak = max(dailyGoal, week.map { $0.xp }.max() ?? 0)
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(week.indices, id: \.self) { i in
                let day = week[i]
                VStack(spacing: 6) {
                    Text(day.xp > 0 ? "\(day.xp)" : "")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(day.xp >= dailyGoal ? Color.vOro : Color.vRojo.opacity(day.xp > 0 ? 0.7 : 0.12))
                        .frame(height: max(6, CGFloat(day.xp) / CGFloat(max(1, peak)) * 110))
                    Text(day.label)
                        .font(.caption2)
                        .foregroundColor(i == week.count - 1 ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 150, alignment: .bottom)
    }

    private func scheduleReminder() {
        Reminder.schedule(hour: reminderHour, minute: reminderMinute) { ok in
            reminderDenied = !ok
            if !ok { reminderOn = false }
        }
    }
}

struct SavedWordsView: View {
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        List {
            if progress.savedItems.isEmpty {
                Text("在查词、阅读、对话里点「加入复习」，词句会出现在这里，并进入复习卡片。")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            ForEach(progress.savedItems) { item in
                HStack(spacing: 12) {
                    SpeakButton(text: item.speakText, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.es).font(.spanish(17, weight: .medium))
                        Text(item.zh).font(.caption).foregroundColor(.secondary)
                    }
                }
                .swipeActions {
                    Button("删除", role: .destructive) { progress.deleteSaved(item.id) }
                }
            }
        }
        .navigationTitle("我收藏的词句")
        .navigationBarTitleDisplayMode(.inline)
    }
}
