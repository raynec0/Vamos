import Foundation

struct ChatScenario: Identifiable, Hashable {
    let id: String
    let level: String
    let title: String
    let icon: String
    /// Scene description given to the AI.
    let setting: String
    /// Who the AI plays.
    let role: String
    /// What the learner should try to do (shown in the app).
    let goal: String

    static let tutor = ChatScenario(
        id: "tutor", level: "", title: "和 Lucía 自由聊天", icon: "person.wave.2",
        setting: "一次轻松的语言交换。对方想练西班牙语，你们随便聊生活、兴趣、工作、西班牙文化。",
        role: "Lucía，28 岁，马德里人，热情健谈的西班牙语老师",
        goal: "想聊什么都可以，Lucía 会配合你的水平")

    static let all: [ChatScenario] = [
        ChatScenario(id: "a1-intercambio", level: "A1", title: "语言交换初次见面", icon: "hand.wave",
                     setting: "马德里一家咖啡馆里的语言交换活动，两个人第一次见面。",
                     role: "Pablo，25 岁，马德里大学生，想学中文", goal: "互相介绍：名字、国籍、职业、住在哪里"),
        ChatScenario(id: "a1-bar", level: "A1", title: "在酒吧点单", icon: "cup.and.saucer",
                     setting: "马德里市中心一家传统酒吧，学习者是顾客。", role: "酒吧服务员（camarero），说话直接、热情",
                     goal: "点饮料和 tapas，问价钱，结账"),
        ChatScenario(id: "a1-calle", level: "A1", title: "街头问路", icon: "map",
                     setting: "塞维利亚老城区，学习者在找大教堂和最近的地铁站。", role: "一位友善的当地老太太",
                     goal: "问路、听懂方向、道谢"),
        ChatScenario(id: "a2-piso", level: "A2", title: "看房租房", icon: "house",
                     setting: "巴伦西亚，学习者要合租一个房间，正在看房。", role: "房东 Marta，四十多岁，有点挑剔",
                     goal: "询问房租、押金、费用、室友和规矩"),
        ChatScenario(id: "a2-medico", level: "A2", title: "看医生", icon: "stethoscope",
                     setting: "社区卫生中心（centro de salud）的诊室。", role: "家庭医生 doctor Ruiz",
                     goal: "描述症状、回答问题、听懂医嘱"),
        ChatScenario(id: "a2-tienda", level: "A2", title: "退换衣服", icon: "bag",
                     setting: "一家服装店，学习者昨天买的衣服尺码不对。", role: "店员，礼貌但会坚持店里的规定",
                     goal: "说明问题，要求换货或退款"),
        ChatScenario(id: "a2-finde", level: "A2", title: "约朋友过周末", icon: "calendar",
                     setting: "通过电话和西班牙朋友商量周末做什么。", role: "朋友 Javi，爱热闹，总有很多主意",
                     goal: "提议、接受或拒绝、约定时间地点"),
        ChatScenario(id: "b1-entrevista", level: "B1", title: "工作面试", icon: "briefcase",
                     setting: "马德里一家公司的面试，职位与学习者的背景相关。", role: "人事经理 Elena García，专业、友善",
                     goal: "介绍经历、回答面试问题、提问"),
        ChatScenario(id: "b1-viaje", level: "B1", title: "讲讲你的旅行", icon: "airplane",
                     setting: "朋友聚会上，大家在聊最近的旅行。", role: "好奇心很强的朋友 Carmen，会不断追问细节",
                     goal: "用过去时生动地讲一次旅行"),
        ChatScenario(id: "b1-reclamacion", level: "B1", title: "餐厅投诉", icon: "fork.knife",
                     setting: "一家餐厅，菜上错了而且等了很久。", role: "餐厅经理，起初有点防备",
                     goal: "礼貌而坚定地投诉，争取补偿"),
        ChatScenario(id: "b1-compis", level: "B1", title: "和室友谈家务", icon: "sparkles",
                     setting: "合租公寓的客厅，家务分配出了问题。", role: "室友 Álex，有点懒但讲道理",
                     goal: "表达不满、提出建议、达成协议"),
        ChatScenario(id: "b2-debate", level: "B2", title: "辩论：远程办公", icon: "laptopcomputer",
                     setting: "一档电台节目的讨论环节，话题是远程办公（teletrabajo）的利弊。", role: "主持人兼对方辩友，立场与学习者相反",
                     goal: "陈述观点、论证、反驳、让步"),
        ChatScenario(id: "b2-noticias", level: "B2", title: "聊聊时事", icon: "newspaper",
                     setting: "下班后和同事喝一杯，聊最近的新闻和社会话题。", role: "同事 Luis，见多识广、爱开玩笑",
                     goal: "评论新闻、表达看法、追问"),
        ChatScenario(id: "b2-reunion", level: "B2", title: "商务谈判", icon: "person.3",
                     setting: "学习者的公司与一家西班牙客户谈订单的价格、交期和质量要求。", role: "客户采购经理 Sr. Navarro，强硬但讲理",
                     goal: "谈判价格和交期、处理异议、达成共识"),
        ChatScenario(id: "c1-sueldo", level: "C1", title: "谈薪水", icon: "banknote",
                     setting: "年度评估会，学习者想争取加薪。", role: "直属上司 Beatriz，精明、预算紧张",
                     goal: "有策略地说服、委婉施压、谈条件"),
        ChatScenario(id: "c1-cultura", level: "C1", title: "聊书和电影", icon: "film",
                     setting: "一家书店的读书会结束后的闲聊。", role: "文学爱好者 Teresa，有自己鲜明的观点",
                     goal: "深入评价作品、谈论主题和风格"),
        ChatScenario(id: "c1-ponencia", level: "C1", title: "演讲后的问答", icon: "mic",
                     setting: "学习者刚在一个行业会议上用西语做完演讲，现在是提问环节。", role: "几位轮流提问的听众，问题有深度，有的带挑战",
                     goal: "得体地回答尖锐问题、澄清和补充"),
        ChatScenario(id: "c2-colegas", level: "C2", title: "和马德里哥们儿闲聊", icon: "flame",
                     setting: "周五晚上在马德里 Malasaña 区的酒吧，几个老朋友聊天。", role: "地道的马德里人 Nacho，满嘴俚语、爱讽刺、语速飞快",
                     goal: "听懂俚语和玩笑，接梗，像本地人一样聊"),
        ChatScenario(id: "c2-tertulia", level: "C2", title: "电台 tertulia", icon: "radio",
                     setting: "一档西班牙电台 tertulia 节目，几位评论员讨论社会文化话题（政治话题保持中立）。", role: "资深评论员，用词讲究、善用反讽和典故",
                     goal: "参与高水平讨论，理解反讽和言外之意"),
        ChatScenario(id: "c2-modismos", level: "C2", title: "地道表达挑战", icon: "quote.bubble",
                     setting: "一个语言游戏：对方说话时会大量使用习语和谚语，学习者要理解并用地道的表达回应。", role: "风趣的老马德里人 Don Paco",
                     goal: "理解并使用习语、谚语")
    ]

    /// A conversation built around one lesson's topic and grammar.
    static func forLesson(_ entry: LessonEntry) -> ChatScenario {
        let lesson = LessonRepository.shared.lesson(for: entry)
        let grammar = entry.spec?.grammar.joined(separator: "；")
            ?? lesson?.tips.map(\.title).joined(separator: "；") ?? ""
        let words = lesson?.items.prefix(12).map(\.es).joined(separator: "、") ?? ""
        return ChatScenario(
            id: "lesson:" + entry.id, level: entry.levelId, title: "练习：" + entry.title, icon: entry.icon,
            setting: "一次围绕「\(entry.title)（\(entry.subtitle)）」的日常对话。请自然地制造机会让学习者使用这些语法：\(grammar)。可以用到这些词：\(words)。",
            role: "Lucía，马德里人，耐心的西语老师，在对话中扮演和主题相关的角色",
            goal: "在真实对话里用上本课的语法和词汇")
    }

    static func find(_ id: String) -> ChatScenario {
        if id == tutor.id { return tutor }
        if id.hasPrefix("lesson:"), let entry = CourseStore.shared.entry(String(id.dropFirst(7))) {
            return forLesson(entry)
        }
        return all.first { $0.id == id } ?? tutor
    }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    var id = UUID()
    var role: AIMessage.Role
    var text: String
    var translation: String? = nil
    var correction: Correction? = nil
}

struct ChatSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var scenarioId: String
    var level: String
    var created = Date()
    var updated = Date()
    var messages: [ChatMessage] = []

    var scenario: ChatScenario { ChatScenario.find(scenarioId) }

    var preview: String {
        messages.last?.text ?? "（还没有消息）"
    }
}

final class ChatStore: ObservableObject {
    static let shared = ChatStore()

    @Published private(set) var sessions: [ChatSession] = []
    private let url: URL

    private init() {
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chats.json")
        if let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([ChatSession].self, from: data) {
            sessions = list
        }
    }

    func session(_ id: UUID) -> ChatSession? { sessions.first { $0.id == id } }

    func create(scenario: ChatScenario, level: String) -> ChatSession {
        let session = ChatSession(scenarioId: scenario.id, level: level)
        sessions.insert(session, at: 0)
        save()
        return session
    }

    func update(_ session: ChatSession) {
        var s = session
        s.updated = Date()
        if let i = sessions.firstIndex(where: { $0.id == s.id }) {
            sessions[i] = s
        } else {
            sessions.insert(s, at: 0)
        }
        sessions.sort { $0.updated > $1.updated }
        save()
    }

    func delete(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        save()
    }

    private func save() {
        // Keep the 60 most recent conversations.
        if sessions.count > 60 { sessions = Array(sessions.prefix(60)) }
        if let data = try? JSONEncoder().encode(sessions) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
