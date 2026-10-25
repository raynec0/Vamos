import SwiftUI

/// Round speaker button.
struct SpeakButton: View {
    let text: String
    var size: CGFloat = 44
    var color: Color = .vRojo

    var body: some View {
        Button {
            TTS.shared.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("朗读")
    }
}

/// Small turtle button for slow playback.
struct SlowSpeakButton: View {
    let text: String
    var size: CGFloat = 44

    var body: some View {
        Button {
            TTS.shared.speak(text, slow: true)
        } label: {
            Image(systemName: "tortoise.fill")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(.vRojo)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.vRojo.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("慢速朗读")
    }
}

struct ProgressBar: View {
    let value: Double
    var color: Color = .vOK

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.vSunken)
                Capsule()
                    .fill(color)
                    .frame(width: max(12, geo.size.width * min(1, max(0, value))))
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                            .padding(.horizontal, 8)
                            .offset(y: -3),
                        alignment: .top
                    )
            }
        }
        .frame(height: 14)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
    }
}

/// The green / red panel shown after checking an answer.
struct FeedbackBar: View {
    enum Phase {
        case idle(canCheck: Bool)
        case correct(title: String, detail: String?)
        case wrong(answer: String, detail: String?)
    }

    let state: Phase
    var checkTitle: String = "检查"
    let onCheck: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state {
            case .idle(let canCheck):
                Button(checkTitle, action: onCheck)
                    .buttonStyle(ChunkyButtonStyle(color: .vRojo, enabled: canCheck))
                    .disabled(!canCheck)

            case .correct(let title, let detail):
                Label(title, systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.vOK)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("继续", action: onContinue)
                    .buttonStyle(ChunkyButtonStyle(color: .vOK))

            case .wrong(let answer, let detail):
                Label("正确答案", systemImage: "xmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.vBad)
                Text(answer)
                    .font(.spanish(19))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("知道了", action: onContinue)
                    .buttonStyle(ChunkyButtonStyle(color: .vBad))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background.ignoresSafeArea(edges: .bottom))
    }

    private var background: Color {
        switch state {
        case .idle: return .vBackground
        case .correct: return Color.vOK.opacity(0.14)
        case .wrong: return Color.vBad.opacity(0.12)
        }
    }
}

/// Instruction line at the top of every exercise.
struct InstructionText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// End-of-session celebration.
struct CompletionView: View {
    let title: String
    let subtitle: String
    let stats: [(icon: String, value: String, label: String, color: Color)]
    let buttonTitle: String
    let onDone: () -> Void
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.vOro.opacity(0.25))
                    .frame(width: 170, height: 170)
                    .scaleEffect(appeared ? 1 : 0.6)
                Text("¡")
                    .font(.system(size: 120, weight: .black, design: .serif))
                    .foregroundColor(.vRojo)
                    .rotationEffect(.degrees(appeared ? 0 : -20))
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.spanish(34, weight: .bold))
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                ForEach(stats.indices, id: \.self) { i in
                    let s = stats[i]
                    VStack(spacing: 6) {
                        Image(systemName: s.icon)
                            .font(.title3)
                            .foregroundColor(s.color)
                        Text(s.value)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        Text(s.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).stroke(s.color.opacity(0.5), lineWidth: 2))
                }
            }
            .padding(.horizontal)
            Spacer()
            if let secondaryTitle, let onSecondary {
                Button(action: onSecondary) {
                    Label(secondaryTitle, systemImage: "bubble.left.and.bubble.right.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: Color.unit("azul")))
                .padding(.horizontal, 20)
            }
            Button(buttonTitle, action: onDone)
                .buttonStyle(ChunkyButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .background(Color.vBackground.ignoresSafeArea())
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

enum Praise {
    static func random() -> String {
        ["¡Muy bien!", "¡Perfecto!", "¡Genial!", "¡Eso es!", "¡Estupendo!"].randomElement() ?? "¡Muy bien!"
    }
}
