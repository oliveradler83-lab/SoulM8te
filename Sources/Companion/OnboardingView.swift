import SwiftData
import SwiftUI
import UIKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var auth: AuthGate

    private enum Step { case hold, face, names }
    @State private var step: Step = .hold
    @State private var progress = 0.0
    @State private var pressing = false
    @State private var companionName = ""
    @State private var userName = ""
    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("COMPANION")
                .font(Theme.font(22, .light))
                .tracking(Theme.logoTracking)
                .foregroundStyle(.white)
            switch step {
            case .hold: holdStep
            case .face: faceStep
            case .names: nameStep
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .onReceive(timer) { _ in
            guard step == .hold else { return }
            progress = pressing ? min(1, progress + 0.03 / 2.5) : max(0, progress - 0.05)
            if progress >= 1 {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                step = .face
            }
        }
    }

    private var holdStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 3)
                Circle().trim(from: 0, to: progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Theme.accent.opacity(0.7), radius: 8)
                Text("\(Int(progress * 100)) %")
                    .font(Theme.font(28)).foregroundStyle(.white)
            }
            .frame(width: 180, height: 180)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in pressing = true }
                .onEnded { _ in pressing = false })
            Text("Halte den Finger auf den Kreis, um dich zu verbinden.")
                .font(Theme.font(15)).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var faceStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "faceid").font(.system(size: 52, weight: .thin)).foregroundStyle(Theme.accent)
            Text("Alles bleibt privat auf diesem Gerät. Bestätige mit Face ID.")
                .font(Theme.font(15)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            if let f = auth.failure {
                Text(f).font(Theme.font(13)).foregroundStyle(.red.opacity(0.8))
            }
            Button("Face ID") { Task { await verify() } }
                .font(Theme.font(17, .regular)).foregroundStyle(Theme.accent)
        }
        .task { await verify() }
    }

    private func verify() async {
        if await auth.authenticate(reason: "Schütze deinen privaten Chat.") { step = .names }
    }

    private var nameStep: some View {
        VStack(spacing: 16) {
            field("Wie soll deine Gefährtin heißen?", text: $companionName)
            field("Und wie heißt du?", text: $userName)
            Button {
                finish()
            } label: {
                Text("Los geht's").font(Theme.font(17, .regular)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(Theme.pill))
                    .overlay(Capsule().stroke(Theme.accent, lineWidth: 1))
            }
            .disabled(companionName.trimmingCharacters(in: .whitespaces).isEmpty
                      || userName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(Theme.font(17)).foregroundStyle(.white)
            .padding(14)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.7), lineWidth: 1))
    }

    private func finish() {
        let p = Profile(companionName: companionName.trimmingCharacters(in: .whitespaces),
                        userName: userName.trimmingCharacters(in: .whitespaces))
        context.insert(p)
        try? context.save()
        Task { await Nudges.requestPermission() }
        auth.unlocked = true
    }
}
