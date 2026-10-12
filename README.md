# Companion

Lokaler, selbstlernender Gefährte-Chatbot für iPhone. Alles läuft on-device (Apple Foundation Models), keine Cloud, keine Kosten.

- `Sources/Companion/` Quellcode, `project.yml` XcodeGen-Projekt
- Daten: SwiftData im Vault-Ordner (FileProtection `.complete`, kein Backup), Face-ID-Sperre
- Nudges: lokale Benachrichtigungen (1/3/7 Tage, 23:40, 8:45), Texte werden beim Hintergrundwechsel generiert
- Testmodus für Nudges: Menü → Gedächtnis → „Testmodus"

Bauen: `brew install xcodegen && xcodegen && open Companion.xcodeproj`, dann Team wählen.
