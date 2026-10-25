import Foundation

struct NewsFeed: Codable, Identifiable, Hashable {
    var id: String { url }
    let name: String
    let url: String

    static let defaults: [NewsFeed] = [
        NewsFeed(name: "El Mundo", url: "https://e00-elmundo.uecdn.es/elmundo/rss/portada.xml"),
        NewsFeed(name: "El País", url: "https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada"),
        NewsFeed(name: "20minutos", url: "https://www.20minutos.es/rss/"),
        NewsFeed(name: "Europa Press", url: "https://www.europapress.es/rss/rss.aspx")
    ]
}

struct NewsArticle: Identifiable, Hashable {
    var id: String { link.isEmpty ? title : link }
    let title: String
    let link: String
    let summary: String
    let date: Date?
    let source: String
}

enum NewsService {
    private static let customKey = "news.customFeeds"

    static var feeds: [NewsFeed] {
        NewsFeed.defaults + customFeeds
    }

    static var customFeeds: [NewsFeed] {
        guard let data = UserDefaults.standard.data(forKey: customKey),
              let list = try? JSONDecoder().decode([NewsFeed].self, from: data) else { return [] }
        return list
    }

    static func addFeed(name: String, url: String) {
        var list = customFeeds
        list.append(NewsFeed(name: name, url: url))
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: customKey) }
    }

    static func removeFeed(_ feed: NewsFeed) {
        let list = customFeeds.filter { $0.url != feed.url }
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: customKey) }
    }

    static func fetch(_ feed: NewsFeed) async throws -> [NewsArticle] {
        guard let url = URL(string: feed.url) else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let parser = RSSParser(source: feed.name)
        return parser.parse(data)
    }

    /// Tries to pull the body paragraphs out of an article page. Returns nil if it doesn't find enough text.
    static func fetchArticleText(_ link: String) async -> String? {
        guard let url = URL(string: link) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        guard let result = try? await URLSession.shared.data(for: request) else { return nil }
        let data = result.0
        let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        return extractParagraphs(html)
    }

    static func extractParagraphs(_ html: String) -> String? {
        var body = html
        // Drop scripts, styles and obvious boilerplate.
        for tag in ["script", "style", "noscript", "header", "footer", "nav", "aside", "figure", "form"] {
            body = body.replacingOccurrences(of: "<\(tag)[\\s\\S]*?</\(tag)>", with: " ",
                                             options: [.regularExpression, .caseInsensitive])
        }
        guard let regex = try? NSRegularExpression(pattern: "<p[^>]*>([\\s\\S]*?)</p>", options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(body.startIndex..., in: body)
        var paragraphs: [String] = []
        for match in regex.matches(in: body, range: range) {
            guard let r = Range(match.range(at: 1), in: body) else { continue }
            let text = cleanHTML(String(body[r]))
            // Skip short fragments like captions, bylines and cookie notices.
            if text.count >= 80, !paragraphs.contains(text) { paragraphs.append(text) }
        }
        let joined = paragraphs.joined(separator: "\n\n")
        return joined.count >= 400 ? joined : nil
    }

    static func cleanHTML(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">",
            "&aacute;": "á", "&eacute;": "é", "&iacute;": "í", "&oacute;": "ó", "&uacute;": "ú",
            "&Aacute;": "Á", "&Eacute;": "É", "&Iacute;": "Í", "&Oacute;": "Ó", "&Uacute;": "Ú",
            "&ntilde;": "ñ", "&Ntilde;": "Ñ", "&uuml;": "ü", "&iquest;": "¿", "&iexcl;": "¡",
            "&laquo;": "«", "&raquo;": "»", "&ldquo;": "“", "&rdquo;": "”", "&hellip;": "…", "&mdash;": "—", "&ndash;": "–"
        ]
        for (k, v) in entities { t = t.replacingOccurrences(of: k, with: v) }
        // Numeric entities like &#233;
        if let regex = try? NSRegularExpression(pattern: "&#(x?[0-9a-fA-F]+);") {
            let ns = t as NSString
            var result = ""
            var last = 0
            for m in regex.matches(in: t, range: NSRange(location: 0, length: ns.length)) {
                result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                let code = ns.substring(with: m.range(at: 1))
                let value = code.hasPrefix("x") ? UInt32(code.dropFirst(), radix: 16) : UInt32(code)
                if let v = value, let scalar = Unicode.Scalar(v) { result.append(Character(scalar)) }
                last = m.range.location + m.range.length
            }
            result += ns.substring(from: last)
            t = result
        }
        return t.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Minimal RSS 2.0 / Atom parser.
private final class RSSParser: NSObject, XMLParserDelegate {
    private let source: String
    private var articles: [NewsArticle] = []
    private var current: [String: String]?
    private var element = ""
    private var buffer = ""

    init(source: String) { self.source = source }

    func parse(_ data: Data) -> [NewsArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.lowercased()
        if name == "item" || name == "entry" {
            current = [:]
        } else if current != nil, name == "link", let href = attributeDict["href"] {
            current?["link"] = href   // Atom
        }
        element = name
        buffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        buffer += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if current != nil {
            switch name {
            case "title": if current?["title"] == nil { current?["title"] = text }
            case "link": if !text.isEmpty { current?["link"] = text }
            case "description", "summary", "content": if current?["summary"] == nil { current?["summary"] = text }
            case "pubdate", "published", "updated", "dc:date": if current?["date"] == nil { current?["date"] = text }
            case "item", "entry":
                if let c = current, let title = c["title"], !title.isEmpty {
                    articles.append(NewsArticle(
                        title: NewsService.cleanHTML(title),
                        link: c["link"] ?? "",
                        summary: NewsService.cleanHTML(c["summary"] ?? ""),
                        date: Self.parseDate(c["date"]),
                        source: source))
                }
                current = nil
            default: break
            }
        }
        buffer = ""
    }

    private static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, d MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
            f.dateFormat = format
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
