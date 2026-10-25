import AVFoundation
import Speech

/// Live Spanish (es-ES) speech recognition for speaking practice and voice input.
final class SpeechRecognizer: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onFinish: ((String) -> Void)?

    deinit { stopEngine() }

    /// Asks for microphone + speech permission, then starts listening.
    func start(onFinish: ((String) -> Void)? = nil) {
        errorMessage = nil
        self.onFinish = onFinish
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.errorMessage = "需要语音识别权限：请到「设置 → Vamos」打开「语音识别」。"
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self.errorMessage = "需要麦克风权限：请到「设置 → Vamos」打开「麦克风」。"
                            return
                        }
                        self.beginRecording()
                    }
                }
            }
        }
    }

    func toggle(onFinish: ((String) -> Void)? = nil) {
        if isRecording { stop() } else { start(onFinish: onFinish) }
    }

    func reset() {
        transcript = ""
        errorMessage = nil
    }

    private func beginRecording() {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "西班牙语语音识别暂时不可用（需要联网，或在系统里下载西班牙语）。"
            return
        }
        TTS.shared.stop()
        stopEngine()
        transcript = ""

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "无法启动麦克风：\(error.localizedDescription)"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            errorMessage = "没有检测到麦克风输入。"
            return
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            errorMessage = "录音启动失败：\(error.localizedDescription)"
            input.removeTap(onBus: 0)
            return
        }
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.finish() }
                }
                if error != nil, self.isRecording { self.finish() }
            }
        }
    }

    /// Stops listening; the final transcript is delivered to `onFinish`.
    func stop() {
        guard isRecording else { return }
        request?.endAudio()
        // Give the recognizer a moment to return the final result.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        guard isRecording else { return }
        isRecording = false
        stopEngine()
        let text = transcript
        let callback = onFinish
        onFinish = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        callback?(text)
    }

    private func stopEngine() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        request = nil
    }
}
