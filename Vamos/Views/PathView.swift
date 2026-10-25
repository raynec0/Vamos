import SwiftUI

/// Home tab: daily status, level picker and the winding lesson path.
struct PathView: View {
    @EnvironmentObject private var progress: ProgressStore
    @ObservedObject private var repository = LessonRepository.shared
    @Binding var tab: RootView.Tab

    @AppStorage(Prefs.dailyGoal) private var dailyGoal = 30
    @AppStorage(Prefs.unlockAll) private var unlockAll = false
    @AppStorage(Prefs.selectedLevel) private var selectedLevel = ""
    @State private var openLesson: LessonEntry?
    @State private var toast: String?
    @State private var showPlacement = false

    private let store = CourseStore.shared

    private var level: LevelEntry? {
        store.level(selectedLevel) ?? store.level(progress.learnerLevel) ?? store.levels.first
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        levelPicker
                        if let level {
                            levelBanner(level)
                            ForEach(Array(level.units.enumerated()), id: \.element.id) { i, unit in
                                unitSection(unit, number: i + 1, levelIndex: store.levelIndex(level.id))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .onAppear {
                    if selectedLevel.isEmpty { selectedLevel = progress.learnerLevel }
                    if let id = progress.currentLessonId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation { proxy.scrollTo(id, anchor: .center) }
                        }
                    }
                }
            }
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle("¡Vamos!")
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.black.opacity(0.8)))
                        .padding(.bottom, 20)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .fullScreenCover(item: $openLesson) { entry in
            LessonLoaderView(entry: entry)
                .environmentObject(progress)
        }
        .sheet(isPresented: $showPlacement) {
            PlacementTestView().environmentObject(progress)
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { if toast == text { toast = nil } }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            statTile(icon: "flame.fill", color: .orange, value: "\(progress.streak)", label: "连续天数")
            ZStack {
                Circle().stroke(Color.vSunken, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(1, Double(progress.todayXP) / Double(max(1, dailyGoal))))
                    .stroke(Color.vOro, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(progress.todayXP)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text("/ \(dailyGoal) XP")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 84, height: 84)
            .frame(maxWidth: .infinity)

            Button { tab = .review } label: {
                statTile(icon: "rectangle.stack.fill", color: .vRojo, value: "\(progress.dueCount)", label: "待复习")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .card()
        .padding(.top, 8)
    }

    private func statTile(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.system(.title2, design: .rounded).weight(.bold)).foregroundColor(.primary)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Levels

    private var levelPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(store.levels.enumerated()), id: \.element.id) { i, l in
                    let selected = l.id == level?.id
                    let unlocked = progress.isLevelUnlocked(i, unlockAll: unlockAll)
                    Button {
                        Haptics.tap()
                        selectedLevel = l.id
                    } label: {
                        HStack(spacing: 4) {
                            if !unlocked { Image(systemName: "lock.fill").font(.caption2) }
                            Text(l.id).font(.system(.headline, design: .rounded))
                        }
                        .foregroundColor(selected ? .white : (unlocked ? .primary : .secondary))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(selected ? Color.unit(l.color) : Color.vCard))
                        .overlay(Capsule().stroke(selected ? Color.clear : Color.vLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func levelBanner(_ level: LevelEntry) -> some View {
        let color = Color.unit(level.color)
        let done = progress.completedCount(inLevel: level.id)
        let total = level.lessons.count
        let index = store.levelIndex(level.id)
        let unlocked = progress.isLevelUnlocked(index, unlockAll: unlockAll)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(level.id).font(.system(size: 34, weight: .black, design: .rounded)).foregroundColor(color)
                VStack(alignment: .leading, spacing: 0) {
                    Text(level.title).font(.headline)
                    Text(level.subtitle).font(.spanish(13, weight: .regular).italic()).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(done)/\(total)").font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundColor(.secondary)
            }
            Text(level.summary).font(.footnote).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            ProgressBar(value: Double(done) / Double(max(1, total)), color: color)
            if index > 0 && !AIClient.shared.isConfigured {
                Label("\(level.id) 的课程由 AI 按大纲生成，请先到「我的 → AI 设置」连接 AI。", systemImage: "sparkles")
                    .font(.caption).foregroundColor(.vOro)
            }
            if !unlocked {
                HStack {
                    Label("完成上一级别全部课程后解锁", systemImage: "lock.fill").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Button("做分级测试") { showPlacement = true }.font(.caption.weight(.bold))
                }
            } else if index == 0 && done == 0 && progress.data.placementLevel == 0 {
                Button { showPlacement = true } label: {
                    Label("已经学过一些西语？做个分级测试跳级", systemImage: "chart.bar.doc.horizontal")
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .card()
    }

    // MARK: Units

    private func unitSection(_ unit: UnitEntry, number: Int, levelIndex: Int) -> some View {
        let color = Color.unit(unit.color)
        let done = unit.lessons.filter { progress.isCompleted($0.id) }.count

        return VStack(spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("第 \(number) 单元 · \(unit.title)").font(.headline)
                    Text(unit.subtitle).font(.spanish(15, weight: .regular).italic()).opacity(0.9)
                }
                Spacer()
                Text("\(done)/\(unit.lessons.count)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.22)))
            }
            .foregroundColor(.white)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color))
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color.opacity(0.5)).offset(y: 4))

            ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { index, lesson in
                lessonNode(lesson, color: color, offset: Self.offsets[index % Self.offsets.count])
                    .id(lesson.id)
            }
        }
        .padding(.top, 6)
    }

    private static let offsets: [CGFloat] = [0, 56, 84, 56, 0, -56, -84, -56]

    private func lessonNode(_ lesson: LessonEntry, color: Color, offset: CGFloat) -> some View {
        let completed = progress.isCompleted(lesson.id)
        let unlocked = progress.isUnlocked(lesson, unlockAll: unlockAll)
        let current = progress.currentLessonId == lesson.id
        let ready = repository.isReady(lesson)
        let fill: Color = unlocked ? color : Color.vSunken

        return Button {
            if unlocked {
                if !ready && !AIClient.shared.isConfigured {
                    showToast("这节课需要 AI 生成：请先到「我的 → AI 设置」连接 AI")
                    return
                }
                Haptics.tap()
                openLesson = lesson
            } else {
                Haptics.error()
                showToast("先完成前面的课程才能解锁")
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    if current {
                        Circle().stroke(color.opacity(0.35), lineWidth: 6).frame(width: 92, height: 92)
                    }
                    Circle().fill(fill.opacity(0.55)).frame(width: 74, height: 74).offset(y: 5)
                    Circle().fill(fill).frame(width: 74, height: 74)
                    Image(systemName: completed ? "checkmark" : (unlocked ? lesson.icon : "lock.fill"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(unlocked ? .white : .vMuted)
                    if completed {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.vOro)
                            .padding(5)
                            .background(Circle().fill(Color.vCard))
                            .offset(x: 28, y: -28)
                    } else if lesson.isAI && !ready && unlocked {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.vOro)
                            .padding(5)
                            .background(Circle().fill(Color.vCard))
                            .offset(x: 28, y: -28)
                    }
                }
                .frame(width: 96, height: 96)

                VStack(spacing: 2) {
                    Text(lesson.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(unlocked ? .primary : .secondary)
                        .multilineTextAlignment(.center)
                    Text(lesson.subtitle)
                        .font(.spanish(12, weight: .regular).italic())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 200)
                if current {
                    Text("开始")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(color))
                }
            }
        }
        .buttonStyle(.plain)
        .offset(x: offset)
    }
}

/// Makes sure a lesson's content exists (generating it with AI if needed), then runs it.
struct LessonLoaderView: View {
    let entry: LessonEntry
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var lesson: Lesson?
    @State private var error: String?
    @State private var messageIndex = 0

    private let messages = ["正在按大纲编写讲解…", "正在挑选地道的例句…", "正在核对西班牙本土用法…", "正在设计练习题…", "快好了，¡un momento!"]
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let lesson {
                LessonFlowView(lesson: lesson, entry: entry)
            } else {
                VStack(spacing: 20) {
                    CloseHeader(title: entry.title) { dismiss() }
                    Spacer()
                    if let error {
                        ErrorCard(message: error) { Task { await load() } }
                            .padding(.horizontal, 20)
                    } else {
                        ProgressView().scaleEffect(1.4)
                        Text(entry.subtitle).font(.spanish(26, weight: .bold))
                        Text(messages[messageIndex % messages.count])
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .animation(.easeInOut, value: messageIndex)
                        Text("第一次打开 AI 课程需要 20–60 秒，之后会保存在手机上。")
                            .font(.caption).foregroundColor(.vMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                }
                .background(Color.vBackground.ignoresSafeArea())
                .onReceive(timer) { _ in messageIndex += 1 }
            }
        }
        .task { await load() }
    }

    private func load() async {
        error = nil
        if let ready = LessonRepository.shared.lesson(for: entry) {
            lesson = ready
            return
        }
        do {
            lesson = try await LessonRepository.shared.generate(entry)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
