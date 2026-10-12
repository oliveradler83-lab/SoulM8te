import Foundation
import NaturalLanguage
import SwiftData

@MainActor
final class ChatEngine: ObservableObject {
    @Published var isTyping = false
    @Published var notice: String?

    private let historyLimit = 8

    func send(_ raw: String, context: ModelContext, profile: Profile) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        context.insert(ChatMessage(text: text, isUser: true))
        try? context.save()

        if let problem = LLM.availabilityMessage {
            notice = problem
            return
        }
        notice = nil
        isTyping = true
        defer { isTyping = false }

        let store = MemoryStore(context: context)
        let facts = store.relevantFacts(for: text).map(\.text)
        let terms = store.relevantTerms(for: text).map { ($0.word, $0.meaning) }
        let rules = store.recentRules().map(\.text)
        let instructions = Persona.instructions(
            companion: profile.companionName, user: profile.userName,
            facts: facts, terms: terms, rules: rules)

        var reply: String?
        for limit in [historyLimit, 3] {
            let prompt = Persona.prompt(history: recentHistory(context, limit: limit),
                                        companion: profile.companionName, user: profile.userName)
            do {
                reply = try await LLM.reply(instructions: instructions, prompt: prompt)
                break
            } catch {
                if Self.isContextOverflow(error) { continue }
                notice = "Antwort fehlgeschlagen: \(error.localizedDescription)"
                return
            }
        }
        guard let reply, !reply.isEmpty else {
            notice = "Ich konnte gerade nicht antworten. Versuch es nochmal."
            return
        }

        let parts = Self.split(reply)
        for part in parts {
            try? await Task.sleep(for: .milliseconds(Int(min(1600, 500 + Double(part.count) * 12))))
            let msg = ChatMessage(text: "", isUser: false)
            context.insert(msg)
            for ch in part {
                msg.text.append(ch)
                try? await Task.sleep(for: .milliseconds(16))
            }
            try? context.save()
        }
        isTyping = false
        await learn(userText: text, botText: reply, context: context, profile: profile)
    }

    private func recentHistory(_ context: ModelContext, limit: Int) -> [(isUser: Bool, text: String)] {
        var d = FetchDescriptor<ChatMessage>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        d.fetchLimit = limit
        let msgs = ((try? context.fetch(d)) ?? []).reversed()
        return msgs.map { (isUser: $0.isUser, text: String($0.text.prefix(400))) }
    }

    private static func isContextOverflow(_ error: Error) -> Bool {
        String(describing: error).lowercased().contains("context")
    }

    static func split(_ text: String) -> [String] {
        var parts = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if parts.count == 1, text.count > 140 {
            let tok = NLTokenizer(unit: .sentence)
            tok.string = text
            var sentences: [String] = []
            tok.enumerateTokens(in: text.startIndex..<text.endIndex) { r, _ in
                sentences.append(String(text[r]).trimmingCharacters(in: .whitespaces)); return true
            }
            if sentences.count > 1 {
                let mid = sentences.count / 2
                parts = [sentences[..<mid].joined(separator: " "), sentences[mid...].joined(separator: " ")]
            }
        }
        if parts.count > 3 {
            parts = [parts[0], parts[1], parts[2...].joined(separator: " ")]
        }
        return parts.isEmpty ? [text] : parts
    }

    // MARK: Lernen

    private func learn(userText: String, botText: String, context: ModelContext, profile: Profile) async {
        let store = MemoryStore(context: context)
        let prompt = """
        Nachricht von \(profile.userName): "\(userText)"
        Antwort von \(profile.companionName): "\(botText)"
        Extrahiere nur Neues aus der Nachricht von \(profile.userName).
        """
        guard let ex = try? await LLM.extract(prompt: prompt) else { return }
        for f in ex.facts { store.addFact(f) }
        for t in ex.terms { store.addTerm(word: t.word, meaning: t.meaning) }
        let mood = ex.mood.trimmingCharacters(in: .whitespaces).lowercased()
        if !mood.isEmpty, mood != "neutral" {
            let day = Date.now.formatted(date: .abbreviated, time: .omitted)
            store.addFact("\(profile.userName) wirkte am \(day) \(mood).", category: "stimmung")
        }
    }

    /// "Klingt komisch": macht aus der Rückmeldung eine Stilregel.
    func feedback(on message: ChatMessage, comment: String, context: ModelContext) async {
        let store = MemoryStore(context: context)
        let fallback = comment.isEmpty
            ? "Formuliere nicht so wie: \"\(message.text.prefix(80))\""
            : "\(comment) (nicht wie: \"\(message.text.prefix(60))\")"
        var rule = fallback
        if LLM.availabilityMessage == nil,
           let r = try? await LLM.reply(
                instructions: "Du formulierst aus Feedback eine kurze Stilregel (ein Satz, Imperativ, max. 15 Wörter) für einen Chat-Gefährten. Nur die Regel, nichts sonst.",
                prompt: "Nachricht: \"\(message.text)\"\nFeedback: \"\(comment.isEmpty ? "klingt komisch" : comment)\"",
                temperature: 0.3, maxTokens: 60) {
            let t = r.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { rule = t }
        }
        store.addRule(rule)
    }
}
