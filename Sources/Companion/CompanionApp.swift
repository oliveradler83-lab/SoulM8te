import SwiftData
import SwiftUI

@main
struct CompanionApp: App {
    private let container = Storage.makeContainer()
    @StateObject private var auth = AuthGate()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .modelContainer(container)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var auth: AuthGate
    @Query private var profiles: [Profile]
    @StateObject private var engine = ChatEngine()

    var body: some View {
        ZStack {
            Theme.background
            if let profile = profiles.first {
                if auth.unlocked {
                    ChatView(profile: profile).environmentObject(engine)
                } else {
                    LockView()
                }
            } else {
                OnboardingView()
            }
            if scenePhase != .active {
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard let profile = profiles.first else { return }
            switch phase {
            case .background:
                auth.lock()
                Storage.harden()
                Task { await Nudges.scheduleAll(context: context, profile: profile) }
            case .active:
                profile.lastOpened = .now
                Task { await Nudges.absorbDelivered(context: context) }
            default:
                break
            }
        }
    }
}

struct LockView: View {
    @EnvironmentObject private var auth: AuthGate

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "faceid")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(Theme.accent)
            if let f = auth.failure {
                Text(f).font(Theme.font(14)).foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Button("Entsperren") { Task { await auth.authenticate(reason: "Dein Chat ist geschützt.") } }
                .font(Theme.font(17, .regular))
                .foregroundStyle(Theme.accent)
        }
        .task { await auth.authenticate(reason: "Dein Chat ist geschützt.") }
    }
}
