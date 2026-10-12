import Foundation
import NaturalLanguage
import SwiftData

@MainActor
struct MemoryStore {
    let context: ModelContext

    private static let embedder = NLEmbedding.sentenceEmbedding(for: .german)

    static func embed(_ text: String) -> [Double]? {
        embedder?.vector(for: text)
    }

    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in a.indices { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
        let d = (na.squareRoot() * nb.squareRoot())
        return d == 0 ? 0 : dot / d
    }

    static func words(_ s: String) -> Set<String> {
        Set(s.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 3 })
    }

    // MARK: Schreiben

    func addFact(_ raw: String, category: String = "fakt") {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 3 else { return }
        let vector = Self.embed(text)
        let existing = (try? context.fetch(FetchDescriptor<Fact>())) ?? []
        for f in existing {
            if f.text.lowercased() == text.lowercased() { f.lastUsed = .now; return }
            if let a = f.embedding, let b = vector, Self.cosine(a, b) > 0.93, f.category == category {
                f.lastUsed = .now
                return
            }
        }
        context.insert(Fact(text: text, category: category, embedding: vector))
        trim(category: "stimmung", keep: 25)
        trim(category: "fakt", keep: 400)
        try? context.save()
    }

    /// Begrenzt eine Kategorie auf die zuletzt benutzten Einträge.
    private func trim(category: String, keep: Int) {
        let all = ((try? context.fetch(FetchDescriptor<Fact>())) ?? [])
            .filter { $0.category == category }
            .sorted { $0.lastUsed > $1.lastUsed }
        guard all.count > keep else { return }
        for f in all.dropFirst(keep) { context.delete(f) }
    }

    func addTerm(word: String, meaning: String) {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty, !m.isEmpty else { return }
        let terms = (try? context.fetch(FetchDescriptor<Term>())) ?? []
        if let t = terms.first(where: { $0.word.lowercased() == w.lowercased() }) {
            t.meaning = m
        } else {
            context.insert(Term(word: w, meaning: m))
        }
        try? context.save()
    }

    func addRule(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        context.insert(StyleRule(text: t))
        let rules = ((try? context.fetch(FetchDescriptor<StyleRule>())) ?? [])
            .sorted { $0.createdAt > $1.createdAt }
        for r in rules.dropFirst(20) { context.delete(r) }
        try? context.save()
    }

    // MARK: Abruf

    /// Einbettungs-Ähnlichkeit + Wortüberschneidung + leichte Aktualität.
    /// Ohne Einbettung zählt nur Wortüberschneidung + Aktualität.
    func relevantFacts(for query: String, limit: Int = 6) -> [Fact] {
        let all = (try? context.fetch(FetchDescriptor<Fact>())) ?? []
        guard !all.isEmpty else { return [] }
        let qVec = Self.embed(query)
        let qWords = Self.words(query)
        let scored: [(Fact, Double)] = all.map { f in
            let fWords = Self.words(f.text)
            let overlap = qWords.isEmpty ? 0 : Double(fWords.intersection(qWords).count) / Double(min(qWords.count, 4))
            let days = Date.now.timeIntervalSince(f.lastUsed) / 86_400
            let recency = exp(-days / 30)
            let score: Double
            if let a = f.embedding, let b = qVec {
                score = 0.55 * max(0, Self.cosine(a, b)) + 0.30 * min(1, overlap) + 0.15 * recency
            } else {
                score = 0.75 * min(1, overlap) + 0.25 * recency
            }
            return (f, score)
        }
        let top = scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
        for f in top { f.lastUsed = .now }
        return Array(top)
    }

    func relevantTerms(for query: String, limit: Int = 5) -> [Term] {
        let q = query.lowercased()
        let all = (try? context.fetch(FetchDescriptor<Term>())) ?? []
        return Array(all.filter { q.contains($0.word.lowercased()) }.prefix(limit))
    }

    func recentRules(limit: Int = 6) -> [StyleRule] {
        let all = (try? context.fetch(FetchDescriptor<StyleRule>())) ?? []
        return Array(all.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }
}
