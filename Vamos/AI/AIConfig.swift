import Foundation
import Security

enum AIProvider: String, CaseIterable, Identifiable {
    case anthropic
    case openai

    var id: String { rawValue }
    var title: String {
        switch self {
        case .anthropic: return "Anthropic（Claude）"
        case .openai: return "OpenAI 兼容接口"
        }
    }
}

struct AIPreset: Identifiable {
    let id: String
    let name: String
    let provider: AIProvider
    let baseURL: String
    let model: String
    let fastModel: String
    let keyURL: String
    let note: String

    static let all: [AIPreset] = [
        AIPreset(id: "claude", name: "Claude", provider: .anthropic,
                 baseURL: "https://api.anthropic.com", model: "claude-sonnet-5-5", fastModel: "claude-haiku-5-5",
                 keyURL: "https://platform.claude.com/", note: "西语质量最好；国内网络需要代理"),
        AIPreset(id: "deepseek", name: "DeepSeek", provider: .openai,
                 baseURL: "https://api.deepseek.com", model: "deepseek-chat", fastModel: "deepseek-chat",
                 keyURL: "https://platform.deepseek.com/", note: "国内直连，价格低"),
        AIPreset(id: "qwen", name: "通义千问", provider: .openai,
                 baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", model: "qwen-plus", fastModel: "qwen-turbo",
                 keyURL: "https://bailian.console.aliyun.com/", note: "国内直连"),
        AIPreset(id: "openai", name: "OpenAI", provider: .openai,
                 baseURL: "https://api.openai.com/v1", model: "gpt-4o", fastModel: "gpt-4o-mini",
                 keyURL: "https://platform.openai.com/api-keys", note: "模型名可按需修改"),
        AIPreset(id: "custom", name: "自定义", provider: .openai,
                 baseURL: "", model: "", fastModel: "",
                 keyURL: "", note: "任意 OpenAI 兼容接口（OpenRouter、Ollama、中转等）")
    ]
}

struct AIConfig {
    var presetId: String
    var provider: AIProvider
    var baseURL: String
    var model: String
    var fastModel: String
    var apiKey: String

    private enum Key {
        static let preset = "ai.preset"
        static let provider = "ai.provider"
        static let baseURL = "ai.baseURL"
        static let model = "ai.model"
        static let fastModel = "ai.fastModel"
        static let keychain = "ai.apiKey"
    }

    var isUsable: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: baseURL) != nil && !baseURL.isEmpty && !model.isEmpty
    }

    var effectiveFastModel: String { fastModel.isEmpty ? model : fastModel }

    static func load() -> AIConfig {
        let d = UserDefaults.standard
        let fallback = AIPreset.all[0]
        return AIConfig(
            presetId: d.string(forKey: Key.preset) ?? fallback.id,
            provider: AIProvider(rawValue: d.string(forKey: Key.provider) ?? "") ?? fallback.provider,
            baseURL: d.string(forKey: Key.baseURL) ?? fallback.baseURL,
            model: d.string(forKey: Key.model) ?? fallback.model,
            fastModel: d.string(forKey: Key.fastModel) ?? fallback.fastModel,
            apiKey: Keychain.read(Key.keychain) ?? ""
        )
    }

    func save() {
        let d = UserDefaults.standard
        d.set(presetId, forKey: Key.preset)
        d.set(provider.rawValue, forKey: Key.provider)
        d.set(baseURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.baseURL)
        d.set(model.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.model)
        d.set(fastModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.fastModel)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { Keychain.delete(Key.keychain) } else { Keychain.write(Key.keychain, value: key) }
        NotificationCenter.default.post(name: .aiConfigChanged, object: nil)
    }

    mutating func apply(_ preset: AIPreset) {
        presetId = preset.id
        provider = preset.provider
        baseURL = preset.baseURL
        model = preset.model
        fastModel = preset.fastModel
    }
}

extension Notification.Name {
    static let aiConfigChanged = Notification.Name("vamos.aiConfigChanged")
}

/// Stores the API key in the Keychain; falls back to UserDefaults if the Keychain is
/// unavailable (can happen with some sideloading / signing setups).
enum Keychain {
    private static let service = "com.raynec.vamos"
    private static func fallbackKey(_ account: String) -> String { "keychain.fallback." + account }

    static func write(_ account: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        if SecItemAdd(insert as CFDictionary, nil) == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: fallbackKey(account))
        } else {
            UserDefaults.standard.set(value, forKey: fallbackKey(account))
        }
    }

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data, let value = String(data: data, encoding: .utf8) {
            return value
        }
        return UserDefaults.standard.string(forKey: fallbackKey(account))
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: fallbackKey(account))
    }
}
