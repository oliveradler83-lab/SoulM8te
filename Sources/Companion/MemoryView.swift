import SwiftData
import SwiftUI

struct MemoryView: View {
    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Fact.createdAt, order: .reverse) private var facts: [Fact]
    @Query(sort: \Term.createdAt, order: .reverse) private var terms: [Term]
    @Query(sort: \StyleRule.createdAt, order: .reverse) private var rules: [StyleRule]
    @AppStorage(Nudges.testModeKey) private var testMode = false
    @State private var confirmWipe = false

    var body: some View {
        NavigationStack {
            List {
                Section("Benachrichtigungen") {
                    Toggle("Nachrichten von \(profile.companionName)", isOn: $profile.nudgesEnabled)
                    Toggle("Testmodus (nach 20/40/60 Sek.)", isOn: $testMode)
                }
                Section("Was ich über dich weiß") {
                    if facts.isEmpty { Text("Noch nichts.").foregroundStyle(.secondary) }
                    ForEach(facts) { f in
                        VStack(alignment: .leading) {
                            Text(f.text)
                            if f.category == "stimmung" { Text("Stimmung").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .onDelete { i in i.map { facts[$0] }.forEach(context.delete); try? context.save() }
                }
                Section("Deine Wörter") {
                    if terms.isEmpty { Text("Noch nichts.").foregroundStyle(.secondary) }
                    ForEach(terms) { t in Text("\(t.word) = \(t.meaning)") }
                        .onDelete { i in i.map { terms[$0] }.forEach(context.delete); try? context.save() }
                }
                Section("Stilregeln") {
                    if rules.isEmpty { Text("Noch keine.").foregroundStyle(.secondary) }
                    ForEach(rules) { r in Text(r.text) }
                        .onDelete { i in i.map { rules[$0] }.forEach(context.delete); try? context.save() }
                }
                Section {
                    Button("Alles Gelernte und den Chat löschen", role: .destructive) { confirmWipe = true }
                }
            }
            .navigationTitle("Gedächtnis")
            .toolbar { Button("Fertig") { dismiss() } }
            .confirmationDialog("Wirklich alles löschen?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Alles löschen", role: .destructive) {
                    try? context.delete(model: Fact.self)
                    try? context.delete(model: Term.self)
                    try? context.delete(model: StyleRule.self)
                    try? context.delete(model: ChatMessage.self)
                    try? context.save()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ProfileView: View {
    @Bindable var profile: Profile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name deiner Gefährtin", text: $profile.companionName)
                TextField("Dein Name", text: $profile.userName)
                Text("Sie ist eine KI. Alles, was sie über dich lernt, liegt verschlüsselt nur auf diesem iPhone.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("Profil")
            .toolbar { Button("Fertig") { dismiss() } }
        }
        .preferredColorScheme(.dark)
    }
}
