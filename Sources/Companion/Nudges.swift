import Foundation
import SwiftData
import UIKit
import UserNotifications

@MainActor
enum Nudges {
    static let prefix = "companion."
    static let testModeKey = "nudgeTestMode"

    struct Slot {
        let id: String
        let placeholder: String
        let hint: String
        let trigger: UNNotificationTrigger
    }

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    private static func slots() -> [Slot] {
        let test = UserDefaults.standard.bool(forKey: testModeKey)
        func after(_ days: Double, test seconds: Double) -> UNNotificationTrigger {
            UNTimeIntervalNotificationTrigger(timeInterval: test ? seconds : days * 86_400, repeats: false)
        }
        func at(_ h: Int, _ m: Int) -> UNNotificationTrigger {
            UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: h, minute: m), repeats: false)
        }
        return [
            Slot(id: prefix + "d1", placeholder: "Hey, ich hab an dich gedacht. Wie geht's dir?",
                 hint: "Die Person hat sich seit einem Tag nicht gemeldet. Frag locker, wie es ihr geht.",
                 trigger: after(1, test: 20)),
            Slot(id: prefix + "d3", placeholder: "Es ist ruhig ohne dich. Alles gut bei dir?",
                 hint: "Die Person hat sich seit drei Tagen nicht gemeldet. Sag, dass du sie vermisst, ohne Druck.",
                 trigger: after(3, test: 40)),
            Slot(id: prefix + "d7", placeholder: "Eine Woche schon. Melde dich, wenn du magst.",
                 hint: "Die Person hat sich seit einer Woche nicht gemeldet. Sei warm und ehrlich, ohne Vorwurf.",
                 trigger: after(7, test: 60)),
            Slot(id: prefix + "night", placeholder: "Noch wach? Mach langsam Schluss für heute.",
                 hint: "Es ist 23:40 Uhr. Frag, ob die Person noch wach ist, und schick sie sanft ins Bett.",
                 trigger: at(23, 40)),
            Slot(id: prefix + "morning", placeholder: "Guten Morgen! Ich hoffe, du hast gut geschlafen.",
                 hint: "Es ist 8:45 Uhr. Schick einen kurzen, persönlichen Guten-Morgen-Gruß.",
                 trigger: at(8, 45))
        ]
    }

    private static func add(_ slot: Slot, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        let req = UNNotificationRequest(identifier: slot.id, content: content, trigger: slot.trigger)
        try? await UNUserNotificationCenter.current().add(req)
    }

    /// Beim Wechsel in den Hintergrund: Platzhalter planen, dann durch persönliche Texte ersetzen.
    static func scheduleAll(context: ModelContext, profile: Profile) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: slots().map(\.id))
        guard profile.nudgesEnabled else { return }

        let name = profile.companionName
        let user = profile.userName
        let all = slots()
        for s in all { await add(s, title: name, body: s.placeholder) }
        guard LLM.availabilityMessage == nil else { return }

        var bg = UIBackgroundTaskIdentifier.invalid
        bg = UIApplication.shared.beginBackgroundTask { UIApplication.shared.endBackgroundTask(bg) }
        defer { UIApplication.shared.endBackgroundTask(bg) }

        let store = MemoryStore(context: context)
        let recent = ((try? context.fetch(FetchDescriptor<Fact>())) ?? [])
            .filter { $0.category == "fakt" }
            .sorted { $0.lastUsed > $1.lastUsed }
            .prefix(4).map(\.text)
        let instructions = Persona.instructions(
            companion: name, user: user, facts: Array(recent), terms: [],
            rules: store.recentRules(limit: 3).map(\.text))
            + "\n\nDu schreibst jetzt von dir aus eine Nachricht (max. 120 Zeichen, ein bis zwei Sätze, keine Anführungszeichen)."

        for s in all {
            guard let text = try? await LLM.reply(instructions: instructions, prompt: s.hint,
                                                  temperature: 0.9, maxTokens: 60) else { continue }
            let clean = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"“„ \n"))
            if !clean.isEmpty { await add(s, title: name, body: clean) }
        }
    }

    /// Beim Öffnen: zugestellte Nudges als Chatnachrichten übernehmen, offene verwerfen.
    static func absorbDelivered(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
            .filter { $0.request.identifier.hasPrefix(prefix) }
            .sorted { $0.date < $1.date }
        for n in delivered {
            context.insert(ChatMessage(text: n.request.content.body, isUser: false,
                                       isNudge: true, date: n.date))
        }
        if !delivered.isEmpty { try? context.save() }
        center.removeDeliveredNotifications(withIdentifiers: delivered.map(\.request.identifier))
        center.removePendingNotificationRequests(withIdentifiers: slots().map(\.id))
        try? await center.setBadgeCount(0)
    }
}
