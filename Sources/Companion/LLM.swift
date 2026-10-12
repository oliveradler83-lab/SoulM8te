import Foundation
import FoundationModels

@Generable
struct TermPair {
    @Guide(description: "Das Wort oder die umgangssprachliche Wendung")
    var word: String
    @Guide(description: "Was die Person damit meint, in einem kurzen Satz")
    var meaning: String
}

@Generable
struct Extraction {
    @Guide(description: "Neue, dauerhaft wichtige Fakten über die Person als kurze deutsche Sätze, z. B. 'Oliver arbeitet im Außendienst.' Leer, wenn nichts Neues.")
    var facts: [String]
    @Guide(description: "Nur Wörter, deren Bedeutung die Person selbst erklärt hat. Sonst leer.")
    var terms: [TermPair]
    @Guide(description: "Stimmung der Person in einem Wort, z. B. müde, gut gelaunt, gestresst, neutral")
    var mood: String
}

/// Kapselt das Sprachmodell, damit es später austauschbar ist.
enum LLM {
    static var availabilityMessage: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            return "Das Sprachmodell ist nicht verfügbar (\(reason)). Prüfe, ob Apple Intelligence in den Einstellungen aktiviert ist."
        }
    }

    static func reply(instructions: String, prompt: String,
                      temperature: Double = 0.85, maxTokens: Int = 220) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(temperature: temperature, maximumResponseTokens: maxTokens)
        let response = try await session.respond(to: prompt, options: options)
        return response.content
    }

    static func extract(prompt: String) async throws -> Extraction {
        let session = LanguageModelSession(instructions:
            "Du analysierst Chatnachrichten und ziehst nur gesicherte Informationen heraus. Erfinde nichts. Antworte auf Deutsch.")
        let response = try await session.respond(to: prompt, generating: Extraction.self)
        return response.content
    }
}
