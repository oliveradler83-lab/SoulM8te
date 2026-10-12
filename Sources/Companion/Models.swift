import Foundation
import SwiftData

@Model final class Profile {
    var companionName: String
    var userName: String
    var nudgesEnabled: Bool
    var createdAt: Date
    var lastOpened: Date

    init(companionName: String, userName: String) {
        self.companionName = companionName
        self.userName = userName
        self.nudgesEnabled = true
        self.createdAt = .now
        self.lastOpened = .now
    }
}

@Model final class Fact {
    var text: String
    var category: String   // "fakt" | "stimmung"
    var createdAt: Date
    var lastUsed: Date
    var embedding: [Double]?

    init(text: String, category: String, embedding: [Double]?) {
        self.text = text
        self.category = category
        self.createdAt = .now
        self.lastUsed = .now
        self.embedding = embedding
    }
}

@Model final class Term {
    var word: String
    var meaning: String
    var createdAt: Date

    init(word: String, meaning: String) {
        self.word = word
        self.meaning = meaning
        self.createdAt = .now
    }
}

@Model final class StyleRule {
    var text: String
    var createdAt: Date

    init(text: String) {
        self.text = text
        self.createdAt = .now
    }
}

@Model final class ChatMessage {
    var id: UUID
    var text: String
    var isUser: Bool
    var isNudge: Bool
    var date: Date

    init(text: String, isUser: Bool, isNudge: Bool = false, date: Date = .now) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
        self.isNudge = isNudge
        self.date = date
    }
}
