import SwiftData
import SwiftUI

struct ChatView: View {
    let profile: Profile
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var engine: ChatEngine
    @Query(sort: \ChatMessage.date) private var messages: [ChatMessage]
    @State private var input = ""
    @State private var showMemory = false
    @State private var showProfile = false
    @State private var feedbackTarget: ChatMessage?
    @State private var feedbackText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(messages) { m in bubble(m).id(m.id) }
                        if engine.isTyping {
                            Text("\(profile.companionName) schreibt…")
                                .font(Theme.font(14)).foregroundStyle(.white.opacity(0.5))
                                .id("typing")
                        }
                        if let n = engine.notice {
                            Text(n).font(Theme.font(13)).foregroundStyle(.orange.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
                .onChange(of: messages.last?.text) { _, _ in scroll(proxy) }
                .onChange(of: messages.count) { _, _ in scroll(proxy) }
                .onChange(of: engine.isTyping) { _, _ in scroll(proxy) }
            }
            inputBar
        }
        .sheet(isPresented: $showMemory) { MemoryView(profile: profile) }
        .sheet(isPresented: $showProfile) { ProfileView(profile: profile) }
        .alert("Was klingt komisch?", isPresented: Binding(
            get: { feedbackTarget != nil }, set: { if !$0 { feedbackTarget = nil } })) {
            TextField("Optional: was genau?", text: $feedbackText)
            Button("Merken") {
                if let m = feedbackTarget {
                    let c = feedbackText
                    Task { await engine.feedback(on: m, comment: c, context: context) }
                }
                feedbackText = ""; feedbackTarget = nil
            }
            Button("Abbrechen", role: .cancel) { feedbackText = ""; feedbackTarget = nil }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            if engine.isTyping { proxy.scrollTo("typing", anchor: .bottom) }
            else if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    private var header: some View {
        HStack {
            Button { showMemory = true } label: { Image(systemName: "line.3.horizontal") }
            Spacer()
            Text(profile.companionName.uppercased())
                .font(Theme.font(18)).tracking(6).foregroundStyle(.white)
            Spacer()
            Button { showProfile = true } label: { Image(systemName: "person.crop.circle") }
        }
        .font(.system(size: 22, weight: .light))
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    @ViewBuilder
    private func bubble(_ m: ChatMessage) -> some View {
        if m.isUser {
            HStack {
                Spacer(minLength: 60)
                Text(m.text)
                    .font(Theme.font(17)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 22).fill(Theme.pill))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.accent, lineWidth: 1))
                    .shadow(color: Theme.accent.opacity(0.45), radius: 8)
            }
        } else {
            HStack {
                Text(m.text)
                    .font(Theme.font(17)).foregroundStyle(.white)
                    .contextMenu {
                        Button("Klingt komisch") { feedbackTarget = m }
                    }
                Spacer(minLength: 40)
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Schreib mir…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .font(Theme.font(17)).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.accent.opacity(0.8), lineWidth: 1))
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36)).foregroundStyle(Theme.accent)
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.isTyping)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func send() {
        let t = input
        input = ""
        Task { await engine.send(t, context: context, profile: profile) }
    }
}
