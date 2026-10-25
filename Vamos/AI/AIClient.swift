import Foundation

struct AIMessage: Codable, Equatable {
    enum Role: String, Codable { case user, assistant }
    var role: Role
    var content: String
}

enum AIError: LocalizedError {
    case notConfigured
    case http(Int, String)
    case emptyResponse
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "还没有设置 AI。请到「我的 → AI 设置」填入 API Key。"
        case .http(let code, let message):
            let hint: String
            switch code {
            case 401, 403: hint = "（API Key 不对或没有权限）"
            case 404: hint = "（接口地址或模型名不对）"
            case 429: hint = "（请求太频繁或额度用完）"
            case 500...599: hint = "（服务暂时不可用，稍后再试）"
            default: hint = ""
            }
            return "AI 请求失败 \(code)\(hint)：\(message.prefix(300))"
        case .emptyResponse:
            return "AI 没有返回内容，请重试。"
        case .invalidJSON(let detail):
            return "AI 返回的格式不对，请重试。\(detail.prefix(200))"
        }
    }
}

/// Talks to either the Anthropic Messages API or any OpenAI-compatible chat completions API.
final class AIClient {
    static let shared = AIClient()

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 120
        c.timeoutIntervalForResource = 300
        return URLSession(configuration: c)
    }()

    var config: AIConfig { AIConfig.load() }
    var isConfigured: Bool { config.isUsable }

    // MARK: Public API

    func complete(system: String, messages: [AIMessage], maxTokens: Int = 2048,
                  fast: Bool = false, temperature: Double? = nil) async throws -> String {
        let cfg = config
        guard cfg.isUsable else { throw AIError.notConfigured }
        let request = try makeRequest(cfg, system: system, messages: messages, maxTokens: maxTokens,
                                      fast: fast, temperature: temperature, stream: false)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw AIError.http(status, Self.errorMessage(from: data))
        }
        let text = try Self.parseCompletion(data, provider: cfg.provider)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AIError.emptyResponse }
        return text
    }

    func stream(system: String, messages: [AIMessage], maxTokens: Int = 1024,
                fast: Bool = false, temperature: Double? = nil) -> AsyncThrowingStream<String, Error> {
        let cfg = config
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard cfg.isUsable else { throw AIError.notConfigured }
                    let request = try self.makeRequest(cfg, system: system, messages: messages, maxTokens: maxTokens,
                                                       fast: fast, temperature: temperature, stream: true)
                    let (bytes, response) = try await self.session.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200..<300).contains(status) else {
                        var body = Data()
                        for try await byte in bytes {
                            body.append(byte)
                            if body.count > 4000 { break }
                        }
                        throw AIError.http(status, Self.errorMessage(from: body))
                    }
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                        if let error = json["error"] as? [String: Any] {
                            throw AIError.http(0, error["message"] as? String ?? "stream error")
                        }
                        if let piece = Self.streamPiece(json, provider: cfg.provider), !piece.isEmpty {
                            continuation.yield(piece)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Asks for JSON and decodes it. Retries once if the reply can't be parsed.
    func json<T: Decodable>(_ type: T.Type, system: String, prompt: String,
                            maxTokens: Int = 4096, fast: Bool = false) async throws -> T {
        var lastError: Error = AIError.emptyResponse
        var messages = [AIMessage(role: .user, content: prompt)]
        for attempt in 0..<2 {
            let raw = try await complete(system: system + "\n\n" + Prompts.jsonRule,
                                         messages: messages, maxTokens: maxTokens, fast: fast,
                                         temperature: attempt == 0 ? nil : 0.3)
            do {
                return try JSONDecoder().decode(T.self, from: Self.extractJSON(raw))
            } catch {
                lastError = AIError.invalidJSON(String(describing: error))
                messages = [
                    AIMessage(role: .user, content: prompt),
                    AIMessage(role: .assistant, content: raw),
                    AIMessage(role: .user, content: "上面的回复不是合法 JSON 或缺少字段（\(error)）。请只输出完整、合法的 JSON，不要任何其它文字。")
                ]
            }
        }
        throw lastError
    }

    /// Raw JSON data from a reply (strips ``` fences and surrounding text).
    static func extractJSON(_ text: String) -> Data {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = t.firstIndex(of: "{"), let end = t.lastIndex(of: "}"), start < end {
            t = String(t[start...end])
        }
        return Data(t.utf8)
    }

    // MARK: Request building

    private func makeRequest(_ cfg: AIConfig, system: String, messages: [AIMessage], maxTokens: Int,
                             fast: Bool, temperature: Double?, stream: Bool) throws -> URLRequest {
        let base = cfg.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let model = fast ? cfg.effectiveFastModel : cfg.model
        var body: [String: Any] = ["model": model, "max_tokens": maxTokens, "stream": stream]
        // Newer Claude models think adaptively and don't take a custom temperature,
        // so it's only sent to OpenAI-compatible endpoints.
        if let temperature, cfg.provider == .openai { body["temperature"] = temperature }

        let urlString: String
        var headers: [String: String] = ["Content-Type": "application/json"]

        switch cfg.provider {
        case .anthropic:
            urlString = base.hasSuffix("/v1") ? base + "/messages" : base + "/v1/messages"
            headers["x-api-key"] = cfg.apiKey
            headers["anthropic-version"] = "2023-06-01"
            body["system"] = system
            body["messages"] = messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        case .openai:
            urlString = base + "/chat/completions"
            headers["Authorization"] = "Bearer " + cfg.apiKey
            var list: [[String: String]] = [["role": "system", "content": system]]
            list += messages.map { ["role": $0.role.rawValue, "content": $0.content] }
            body["messages"] = list
        }

        guard let url = URL(string: urlString) else { throw AIError.http(0, "接口地址无效：\(urlString)") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        if stream { request.setValue("text/event-stream", forHTTPHeaderField: "Accept") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: Response parsing

    private static func parseCompletion(_ data: Data, provider: AIProvider) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.emptyResponse
        }
        switch provider {
        case .anthropic:
            let blocks = json["content"] as? [[String: Any]] ?? []
            return blocks.filter { ($0["type"] as? String) == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
        case .openai:
            let choices = json["choices"] as? [[String: Any]] ?? []
            let message = choices.first?["message"] as? [String: Any]
            return message?["content"] as? String ?? ""
        }
    }

    private static func streamPiece(_ json: [String: Any], provider: AIProvider) -> String? {
        switch provider {
        case .anthropic:
            guard (json["type"] as? String) == "content_block_delta",
                  let delta = json["delta"] as? [String: Any],
                  (delta["type"] as? String) == "text_delta" else { return nil }
            return delta["text"] as? String
        case .openai:
            let choices = json["choices"] as? [[String: Any]] ?? []
            let delta = choices.first?["delta"] as? [String: Any]
            return delta?["content"] as? String
        }
    }

    private static func errorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                return message
            }
            if let message = json["message"] as? String { return message }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
