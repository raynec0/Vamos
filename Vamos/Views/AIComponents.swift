import SwiftUI

/// Shown when a feature needs AI but no API key is set.
struct AISetupPrompt: View {
    var message: String = "这个功能需要连接 AI。"
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.vOro)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("支持 Claude、DeepSeek、通义千问、OpenAI 或任何 OpenAI 兼容接口。填入你自己的 API Key 即可。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("去设置 AI") { showSettings = true }
                .buttonStyle(ChunkyButtonStyle())
                .frame(maxWidth: 260)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showSettings) {
            NavigationStack { AISettingsView() }
        }
    }
}

struct ErrorCard: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("出错了", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.vBad)
            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if let retry {
                Button("重试", action: retry)
                    .buttonStyle(ChunkyButtonStyle(color: .vBad))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct LoadingCard: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(text).font(.subheadline).foregroundColor(.secondary)
            Spacer()
        }
        .card()
    }
}

// MARK: - Tap any word to look it up

/// Spanish text where every word is tappable (opens the dictionary).
struct TappableText: View {
    let text: String
    var font: Font = .spanish(19, weight: .regular)
    var lineSpacing: CGFloat = 6
    @EnvironmentObject private var progress: ProgressStore
    @State private var lookup: LookupWord?

    private static let urlSafe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    var body: some View {
        Text(Self.attributed(text))
            .font(font)
            .lineSpacing(lineSpacing)
            .tint(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "vamoslookup",
                   let word = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "q" })?.value {
                    lookup = LookupWord(word: word, context: text)
                    return .handled
                }
                return .systemAction
            })
            .sheet(item: $lookup) { item in
                LookupSheet(word: item.word, context: item.context)
                    .environmentObject(progress)
            }
    }

    static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString()
        var token = ""
        var tokenIsWord = false

        func flush() {
            guard !token.isEmpty else { return }
            var piece = AttributedString(token)
            if tokenIsWord,
               let encoded = token.addingPercentEncoding(withAllowedCharacters: urlSafe),
               let url = URL(string: "vamoslookup://w?q=\(encoded)") {
                piece.link = url
            }
            result += piece
            token = ""
        }

        for ch in text {
            let isWord = ch.isLetter
            if !token.isEmpty && isWord != tokenIsWord { flush() }
            tokenIsWord = isWord
            token.append(ch)
        }
        flush()
        return result
    }
}

struct LookupWord: Identifiable {
    var id: String { word }
    let word: String
    var context: String? = nil
}

/// Dictionary entry for a single word, with "save to review".
struct LookupSheet: View {
    let word: String
    var context: String? = nil
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss

    @State private var entry: DictionaryEntry?
    @State private var error: String?
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !AIClient.shared.isConfigured {
                        AISetupPrompt(message: "查词需要连接 AI。")
                    } else if let entry {
                        DictionaryEntryView(entry: entry)
                    } else if let error {
                        ErrorCard(message: error) { Task { await load() } }
                    } else {
                        LoadingCard(text: "正在查「\(word)」…")
                    }
                }
                .padding(16)
            }
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle(word)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let entry {
                        Button(saved ? "已加入" : "加入复习") {
                            progress.saveItem(es: entry.lemma ?? entry.word,
                                              zh: entry.meanings.map(\.zh).prefix(2).joined(separator: "；"),
                                              note: entry.pos, pron: entry.ipa)
                            saved = true
                            Haptics.success()
                        }
                        .disabled(saved)
                    }
                }
            }
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
    }

    private func load() async {
        guard AIClient.shared.isConfigured, entry == nil else { return }
        error = nil
        do {
            let result = try await AITasks.lookup(word, level: progress.learnerLevel)
            entry = result
            saved = progress.isSaved(es: result.lemma ?? result.word)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct DictionaryEntryView: View {
    let entry: DictionaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(entry.lemma ?? entry.word)
                    .font(.spanish(30, weight: .bold))
                SpeakButton(text: entry.lemma ?? entry.word, size: 36)
                Spacer()
            }
            HStack(spacing: 8) {
                if let ipa = entry.ipa, !ipa.isEmpty {
                    Text(ipa).font(.system(.subheadline, design: .monospaced)).foregroundColor(.secondary)
                }
                if let pos = entry.pos, !pos.isEmpty {
                    Text(pos)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.vRojo.opacity(0.12)))
                        .foregroundColor(.vRojo)
                }
            }
            if let forms = entry.forms, !forms.isEmpty {
                Label(forms, systemImage: "arrow.triangle.branch")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ForEach(Array(entry.meanings.enumerated()), id: \.offset) { i, m in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(i + 1). \(m.zh)").font(.body.weight(.semibold))
                    if let es = m.example_es, !es.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Button { TTS.shared.speak(es) } label: {
                                Image(systemName: "speaker.wave.2").foregroundColor(.vRojo)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(es).font(.spanish(16, weight: .regular))
                                if let zh = m.example_zh { Text(zh).font(.caption).foregroundColor(.secondary) }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }

            if let spain = entry.spain, !spain.isEmpty {
                infoBlock("西班牙用法", spain, icon: "globe.europe.africa")
            }
            if let c = entry.collocations, !c.isEmpty {
                infoBlock("常见搭配", c.joined(separator: " · "), icon: "link")
            }
            if let s = entry.synonyms, !s.isEmpty {
                infoBlock("近义词", s.joined(separator: " · "), icon: "equal.circle")
            }
            Link(destination: URL(string: "https://dle.rae.es/\((entry.lemma ?? entry.word).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")")!) {
                Label("在 RAE 词典中查看", systemImage: "safari")
                    .font(.subheadline)
            }
        }
    }

    private func infoBlock(_ title: String, _ text: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.caption.weight(.bold)).foregroundColor(.secondary)
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Microphone button

struct MicButton: View {
    @ObservedObject var recognizer: SpeechRecognizer
    var size: CGFloat = 64
    var onFinish: (String) -> Void

    var body: some View {
        Button {
            Haptics.tap()
            recognizer.toggle(onFinish: onFinish)
        } label: {
            ZStack {
                if recognizer.isRecording {
                    Circle()
                        .stroke(Color.vRojo.opacity(0.35), lineWidth: 6)
                        .frame(width: size + 16, height: size + 16)
                }
                Circle()
                    .fill(recognizer.isRecording ? Color.vRojo : Color.vRojo.opacity(0.12))
                    .frame(width: size, height: size)
                Image(systemName: recognizer.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(recognizer.isRecording ? .white : .vRojo)
            }
            .frame(width: size + 16, height: size + 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recognizer.isRecording ? "停止录音" : "开始录音")
    }
}

/// Colours each word of the target sentence green / red after a speaking attempt.
struct PronunciationResultView: View {
    let words: [AnswerChecker.WordMatch]
    let score: Double
    let heard: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(Int((score * 100).rounded()))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text("分").foregroundColor(.secondary)
                Spacer()
                Text(verdict).font(.headline).foregroundColor(color)
            }
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(words) { w in
                    Text(w.word)
                        .font(.spanish(18, weight: .medium))
                        .foregroundColor(w.matched ? .vOK : .vBad)
                        .underline(!w.matched)
                }
            }
            Text("识别到：\(heard.isEmpty ? "（没有听清）" : heard)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var color: Color { score >= 0.85 ? .vOK : (score >= 0.6 ? .vOro : .vBad) }
    private var verdict: String { score >= 0.85 ? "¡Muy bien!" : (score >= 0.6 ? "不错，再试试" : "再听一遍原音") }
}
