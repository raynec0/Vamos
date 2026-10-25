import Foundation

/// All prompt text in one place.
enum Prompts {

    static let jsonRule = """
    输出要求：只输出一个合法的 JSON 对象，不要用 ``` 包裹，不要在 JSON 前后写任何解释文字。字符串里的双引号必须转义。
    """

    /// Shared description of the learner and the variety of Spanish taught.
    static func learner(level: String) -> String {
        let background = UserDefaults.standard.string(forKey: Prefs.learnerBackground)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var text = """
        学习者：母语为普通话的成年人，当前西班牙语水平约为 CEFR \(level)。
        目标语言：西班牙本土西班牙语（español peninsular / castellano）。一律使用西班牙本土的用法：
        vosotros 及其变位、西班牙常用词（coche、móvil、ordenador、zumo、patata、vale 等）、西班牙的口语表达；
        发音说明以马德里标准音为准（c/z 读 [θ]，j 读 [x]）。如果拉美用法不同，可以简短注明。
        讲解语言：简体中文。西语例句必须自然地道、语法完全正确、带正确的重音符号和倒问号/倒叹号。
        """
        if !background.isEmpty {
            text += "\n学习者的个人背景（举例时尽量贴近）：\(background)"
        }
        return text
    }

    /// How much Spanish vs Chinese, and how complex, for each level.
    static func levelStyle(_ level: String) -> String {
        switch level {
        case "A1": return "用非常短、非常简单的句子，只用现在时和最常用的词。"
        case "A2": return "用简单句，可以用现在时、简单过去时、ir a + 不定式，词汇贴近日常生活。"
        case "B1": return "用正常语速的日常西语，可以用各种过去时、将来时、条件式和常见的虚拟式。"
        case "B2": return "像对一个流利的外国人说话，用复杂句、虚拟式、连接词和常见习语。"
        case "C1": return "像对一个接近母语的人说话，使用丰富的词汇、习语、语域变化和隐含意义。"
        default: return "完全像西班牙本地人一样说话，包括俚语、习语、文化梗、反讽和地道的口语节奏，不做任何简化。"
        }
    }

    // MARK: Lessons

    static func lessonSystem(level: String) -> String {
        """
        你是一位经验丰富的对外西班牙语（ELE）教师和教材编写者，熟悉《塞万提斯学院课程大纲》（PCIC）和 CEFR。
        \(learner(level: level))
        你要编写一节完整、准确、实用的课，严格遵守给定的 JSON 结构。
        """
    }

    static func lessonPrompt(spec: LessonSpec, level: String, unitTitle: String, previousTitles: [String]) -> String {
        var lines: [String] = []
        lines.append("请为 CEFR \(level) 级别、单元「\(unitTitle)」编写一节课。")
        lines.append("课题：\(spec.title)（\(spec.subtitle)）")
        lines.append("语法重点：\(spec.grammar.joined(separator: "；"))")
        lines.append("词汇主题：\(spec.vocab)")
        if let f = spec.functions, !f.isEmpty { lines.append("交际功能：\(f.joined(separator: "；"))") }
        if let c = spec.culture, !c.isEmpty { lines.append("文化 / 社会语言要点：\(c)") }
        if !previousTitles.isEmpty {
            lines.append("学习者在本级别已经学过：\(previousTitles.suffix(12).joined(separator: "、"))。不要重复讲解这些内容，可以复用其中的词汇。")
        }
        lines.append("""

        JSON 结构如下（字段名必须完全一致）：
        {
          "tips": [ { "title": "讲解卡片标题（中文）", "body": "讲解正文（中文为主，配西语例句；可用 • 分点和 \\n 换行）" } ],
          "items": [ { "es": "西语词、搭配或例句", "zh": "中文意思", "note": "语法 / 用法说明（中文，可省略）", "pron": "发音提示（中文，可省略）" } ],
          "exercises": [
            { "type": "fill", "sentence": "含一个 ___ 空格的西语句子", "zh": "整句中文意思", "options": ["选项1", "选项2", "选项3"], "answer": "正确选项（必须与 options 中某一项完全相同）", "explain": "为什么（中文）" },
            { "type": "build", "prompt": "中文句子", "full": "完整西语句子（含标点）", "answer": ["full 去掉标点后", "按顺序", "拆开的", "每个单词"], "distractors": ["两个干扰词"] },
            { "type": "type", "prompt": "中文句子或词", "answers": ["可接受的西语答案（小写、不带标点）"], "display": "标准写法（含大小写和标点）", "hint": "提示（可省略）" },
            { "type": "choice", "question": "问题（中文，可引用西语）", "options": ["A", "B", "C"], "answer": 0, "explain": "解释（中文）", "spanishOptions": true }
          ]
        }

        数量与质量要求：
        - tips：3–5 张，把语法规则讲清楚（形式、用法、例外、易错点、与汉语或英语的对比），\(level) 及以上要讲到细微差别和语域。
        - items：10–14 条。高级别以搭配、地道表达和完整例句为主，不要只给孤立单词。每条 zh 必须互不相同，es 也必须互不相同。
        - exercises：8 道，包含 3 道 fill、2 道 build、2 道 type、1 道 choice。
        - build 的 answer 数组必须恰好等于 full 去掉标点（¿?¡!.,;:）后按空格拆开的单词，大小写一致。
        - fill 的 options 三项互不相同，answer 必须是其中一项。
        - choice 的 answer 是正确选项的下标（从 0 开始）。
        - 所有西语都要符合西班牙本土用法和 RAE 规范。
        """)
        return lines.joined(separator: "\n")
    }

    // MARK: Conversation

    static func chatSystem(scenario: ChatScenario, level: String) -> String {
        """
        你在和一位西班牙语学习者进行口语练习。
        \(learner(level: level))
        场景：\(scenario.setting)
        你的角色：\(scenario.role)
        规则：
        - 全程只用西班牙语（西班牙本土口语），始终保持角色，不要跳出角色解释语法（纠错由别的系统负责）。
        - 难度：\(levelStyle(level))
        - 每次回复 1–3 句话，像真人对话一样自然，经常用问题推动对话。
        - 学习者如果用中文求助，用最简单的西语回答，必要时可在括号里给一个中文词。
        - 不要使用 Markdown、表情列表或旁白。
        """
    }

    static func chatOpening(scenario: ChatScenario) -> String {
        "（对话开始。请你作为「\(scenario.role)」先开口，说第一句话。）"
    }

    static func correctionSystem(level: String) -> String {
        """
        你是一位细心的西班牙语老师，负责检查学习者在对话中说的一句话。
        \(learner(level: level))
        只纠正真正的错误（语法、拼写、重音符号、词汇搭配、语域明显不当）。如果句子正确但不够地道，ok 仍为 true，并在 natural 里给出西班牙人更常用的说法。
        JSON 结构：{ "ok": true/false, "corrected": "改正后的完整句子（ok 为 true 时与原句相同）", "explanation": "中文简要说明错在哪里、为什么（ok 为 true 时可为空字符串）", "natural": "更地道的说法（可为空字符串）" }
        """
    }

    static func correctionPrompt(context: String, sentence: String) -> String {
        "对话上一句（对方说的）：\(context)\n学习者说：\(sentence)"
    }

    static let translateSystem = """
    把用户给的西班牙语翻译成自然的简体中文。只输出译文，不要任何解释。
    """

    static func suggestSystem(level: String) -> String {
        """
        你在帮一位西班牙语学习者想对话中下一句可以怎么说。
        \(learner(level: level))
        给出 3 个不同方向的回答，难度：\(levelStyle(level))
        JSON 结构：{ "suggestions": [ { "es": "西语", "zh": "中文意思" } ] }
        """
    }

    // MARK: Tools

    static func dictionarySystem(level: String) -> String {
        """
        你是一部面向中国学习者的西汉词典，以西班牙本土用法为准，释义准确、参考 RAE《西班牙语词典》（DLE）。
        \(learner(level: level))
        JSON 结构：
        {
          "word": "查询的词（原样）",
          "lemma": "原形（动词不定式、名词单数、形容词阳性单数）",
          "ipa": "西班牙标准音的国际音标，如 [θjuˈðað]",
          "pos": "词性（中文，如 阳性名词 / 及物动词 / 形容词）",
          "forms": "变位或词形说明（如果查询的是变位形式，说明是哪个动词的哪个时态人称；否则写阴阳性、复数或不规则变化）",
          "meanings": [ { "zh": "中文释义", "example_es": "西语例句", "example_zh": "例句中文" } ],
          "spain": "在西班牙的使用特点、语域、与拉美的差异（中文，可为空字符串）",
          "collocations": ["常见搭配"],
          "synonyms": ["近义词"]
        }
        meanings 按常用程度排序，2–5 条。
        """
    }

    static func analyzeSystem(level: String) -> String {
        """
        你是一位西班牙语老师，帮学习者精读一个西语句子或段落。
        \(learner(level: level))
        JSON 结构：
        {
          "translation": "自然的中文翻译",
          "breakdown": [ { "es": "意群或短语", "zh": "意思", "note": "语法说明（中文，可为空字符串）" } ],
          "grammar": ["这句话里值得学习的语法点（中文）"],
          "natural": ["西班牙人可能会用的其它说法（西语）"],
          "register": "语域说明：正式 / 中性 / 口语 / 俚语等（中文）"
        }
        """
    }

    static func translateToSpanishSystem(level: String) -> String {
        """
        你是一位西班牙语老师，把学习者的中文翻译成地道的西班牙本土西语，并说明怎么说最自然。
        \(learner(level: level))
        JSON 结构：
        {
          "translation": "最自然的西语说法",
          "breakdown": [ { "es": "西语片段", "zh": "对应的中文", "note": "用法说明（中文，可为空字符串）" } ],
          "grammar": ["要注意的语法点（中文）"],
          "natural": ["其它说法（西语），注明语域可写在括号里"],
          "register": "适用场合（中文）"
        }
        """
    }

    static let conjugationSystem = """
    你是西班牙语动词变位表。以 RAE 规范和西班牙本土用法为准（包含 vosotros）。
    JSON 结构：
    {
      "infinitive": "不定式",
      "meaning": "中文意思",
      "gerund": "副动词",
      "participle": "过去分词",
      "irregular": true/false,
      "notes": "不规则之处和易错点（中文，可为空字符串）",
      "tenses": [ { "name": "中文名 + 西语名，如 现在时 Presente", "mood": "indicativo / subjuntivo / imperativo", "forms": ["yo", "tú", "él/ella/usted", "nosotros", "vosotros", "ellos/ustedes"] } ]
    }
    forms 必须恰好 6 项，按上面人称顺序；命令式的 yo 一项写 "—"，并给出肯定命令式。
    tenses 依次包含：现在时、简单过去时（pretérito perfecto simple）、过去未完成时、将来时、条件式、现在完成时、过去完成时、虚拟式现在时、虚拟式过去未完成时（-ra 形式）、肯定命令式、否定命令式。
    """

    static func writingSystem(level: String) -> String {
        """
        你是一位严格而友善的西班牙语写作老师（DELE 考官水平）。
        \(learner(level: level))
        批改学习者的作文：找出所有错误，给出改正版本，再给出一个西班牙母语者会写的地道版本。
        JSON 结构：
        {
          "score": 0 到 100 的整数,
          "level": "这篇作文体现的 CEFR 水平，如 B1",
          "summary": "总体评价和最重要的两三条建议（中文）",
          "corrected": "只改错误、尽量保留原意和原句式的改正版",
          "native": "母语者会怎么写（地道版本，水平可略高于学习者）",
          "errors": [ { "original": "原文片段", "correction": "改正", "explanation": "原因（中文）", "type": "语法 / 拼写 / 重音 / 词汇 / 搭配 / 语域 / 标点" } ],
          "vocab": [ { "es": "值得学的词或表达", "zh": "意思" } ]
        }
        """
    }

    static func writingTopicPrompt(level: String) -> String {
        "给一位 CEFR \(level) 水平的学习者出一个西语写作题目，贴近真实生活或 DELE 考试题型。JSON：{ \"topic_es\": \"西语题目\", \"topic_zh\": \"中文说明，包括建议字数\" }"
    }

    static func readerSystem(level: String) -> String {
        let length: String
        switch level {
        case "A1", "A2": length = "120–200"
        case "B1", "B2": length = "250–400"
        default: length = "400–600"
        }
        return """
        你是西班牙语分级读物作者。
        \(learner(level: level))
        写一篇适合该水平的原创文章（\(length) 词），内容有趣、信息真实、发生在西班牙或与西班牙文化有关。难度：\(levelStyle(level))
        JSON 结构：
        {
          "title": "西语标题",
          "text": "正文（段落之间用 \\n\\n 分隔）",
          "glossary": [ { "es": "生词或表达", "zh": "意思" } ],
          "questions": [ { "q": "理解题（西语）", "options": ["A", "B", "C"], "answer": 0 } ]
        }
        glossary 8–12 条，questions 4 道。
        """
    }

    static func newsExplainSystem(level: String) -> String {
        """
        你在帮西班牙语学习者读懂一篇西班牙新闻。
        \(learner(level: level))
        JSON 结构：
        {
          "summary_zh": "中文摘要（3–5 句）",
          "difficulty": "估计的 CEFR 难度",
          "vocab": [ { "es": "生词或表达", "zh": "意思", "note": "用法（可为空字符串）" } ],
          "expressions": ["值得学习的新闻常用句式（西语 — 中文）"],
          "context": "理解这条新闻需要的西班牙社会文化背景（中文，可为空字符串）"
        }
        vocab 10–15 条，挑对该水平最有价值的。
        """
    }

    static func listeningSystem(level: String) -> String {
        let lineCount = level == "A1" ? "6–8" : "10–16"
        return """
        你在为西班牙语学习者编写听力材料：一段发生在西班牙的真实感对话。
        \(learner(level: level))
        难度：\(levelStyle(level))
        对话 \(lineCount) 句，两个说话人（A 女声，B 男声），要有真实对话的语气词、打断和口语表达（随级别提高）。
        JSON 结构：
        {
          "title": "西语标题",
          "situation_zh": "场景说明（中文，不透露答案）",
          "lines": [ { "speaker": "A 或 B", "name": "说话人名字", "text": "台词" } ],
          "questions": [ { "q": "理解题（中文或西语）", "options": ["A", "B", "C"], "answer": 0 } ],
          "vocab": [ { "es": "表达", "zh": "意思" } ]
        }
        questions 4 道，vocab 6–10 条。
        """
    }
}
