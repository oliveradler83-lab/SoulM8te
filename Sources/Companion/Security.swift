import Foundation
import LocalAuthentication
import SwiftData

@MainActor
final class AuthGate: ObservableObject {
    @Published var unlocked = false
    @Published var failure: String?

    @discardableResult
    func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            failure = "Auf diesem Gerät ist weder Face ID noch ein Code eingerichtet."
            return false
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            unlocked = ok
            failure = nil
            return ok
        } catch {
            failure = error.localizedDescription
            return false
        }
    }

    func lock() { unlocked = false }
}

enum Storage {
    static let vaultURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var url = base.appendingPathComponent("Vault", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return url
    }()

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Profile.self, Fact.self, Term.self, StyleRule.self, ChatMessage.self])
        let config = ModelConfiguration(
            schema: schema,
            url: vaultURL.appendingPathComponent("companion.store"),
            cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            harden()
            return container
        } catch {
            fatalError("Tresor konnte nicht geöffnet werden: \(error)")
        }
    }

    /// Setzt auf alle Dateien im Tresor vollen Dateischutz und schließt sie vom Backup aus.
    static func harden() {
        let fm = FileManager.default
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: vaultURL.path)
        guard let files = try? fm.contentsOfDirectory(at: vaultURL, includingPropertiesForKeys: nil) else { return }
        for var file in files {
            try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? file.setResourceValues(values)
        }
    }
}
