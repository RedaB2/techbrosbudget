//
//  BudgetChatView.swift
//  techbrosbudget
//

import SwiftUI

// Single source of truth for the input bar height so buttons and text field
// always render at the same size regardless of font metrics or button style padding.
private let kInputHeight: CGFloat = 44

struct BudgetChatView: View {
    let store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var session = BudgetChatSession()
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ChatBackground()

            VStack(spacing: 0) {
                chatHeader
                messagesView
                inputRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                    .padding(.top, 8)
            }
        }
        .onChange(of: session.liveTranscription) { _, text in
            if !text.isEmpty { inputText = text }
        }
        .onAppear { session.open(store: store) }
        .onDisappear { session.stopRecording() }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 12) {
            TechBroAvatar(size: 40)

            Text("Tech Bro")
                .font(.headline)

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Monolith.secondary)
            }
            .buttonStyle(MonolithRingButtonStyle(diameter: 36))
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Messages

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if session.messages.isEmpty && !session.isResponding {
                        welcomeBubble
                    }

                    ForEach(session.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                            .transition(.opacity)
                    }

                    if !session.streamingContent.isEmpty {
                        AssistantBubble(content: session.streamingContent, isStreaming: true)
                            .id("streaming")
                    } else if session.isResponding {
                        TypingBubble()
                            .id("typing")
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
            .onChange(of: session.messages.count) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    proxy.scrollTo("bottom")
                }
            }
            .onChange(of: session.streamingContent) {
                proxy.scrollTo("bottom")
            }
            .onChange(of: session.isResponding) {
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
    }

    @ViewBuilder
    private var welcomeBubble: some View {
        if session.isModelAvailable {
            VStack(alignment: .leading, spacing: 14) {
                AssistantBubble(
                    content: "What's your budget situation looking like? Ask me anything: biggest spends, where to cut costs, category breakdowns, whatever you need.",
                    isStreaming: false
                )
                suggestionChips
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Not Available")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Monolith.negative)

                    Text("Apple Intelligence isn't enabled. Head to Settings → Apple Intelligence & Siri to turn it on.")
                        .font(.subheadline)
                        .foregroundStyle(Monolith.secondary)
                }

                Spacer(minLength: 40)
            }
            .padding(14)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Monolith.hairline, lineWidth: 1)
            }
        }
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Self.suggestions, id: \.self) { prompt in
                Button {
                    Task { await session.send(prompt) }
                } label: {
                    Text(prompt)
                        .font(.subheadline)
                        .foregroundStyle(Monolith.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .overlay {
                            Capsule().strokeBorder(Monolith.ring, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(session.isResponding)
            }
        }
        .padding(.leading, 4)
    }

    private static let suggestions = [
        "What are my biggest spends?",
        "Where can I cut costs?",
        "Break down my spending by category",
    ]

    // MARK: - Input row
    //
    // Three independent floating elements in a bottom-aligned HStack.
    // Every element is anchored to kInputHeight so their bottom edges are flush
    // at single-line size. The text field uses `frame(minHeight:)` so it grows
    // upward naturally when text wraps, while the buttons stay pinned to bottom.

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            micButton
            messageTextField
            sendButton
        }
    }

    private var micButton: some View {
        Button {
            if session.isRecording {
                session.stopRecording()
            } else {
                Task { await session.startRecording() }
            }
        } label: {
            Image(systemName: session.isRecording ? "stop.fill" : "mic")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(session.isRecording ? Monolith.negative : Monolith.secondary)
        }
        .buttonStyle(MonolithRingButtonStyle(diameter: kInputHeight))
        .symbolEffect(.pulse, isActive: session.isRecording)
        .accessibilityLabel(session.isRecording ? "Stop recording" : "Record voice message")
    }

    private var messageTextField: some View {
        TextField(
            session.isRecording && session.liveTranscription.isEmpty
                ? "Listening…"
                : "Message Tech Bro…",
            text: $inputText,
            axis: .vertical
        )
        .font(.subheadline)
        .lineLimit(1...5)
        .padding(.horizontal, 16)
        // Vertical padding is calculated so that:
        // topPad + lineHeight + bottomPad == kInputHeight
        // subheadline line height ≈ 20 pt → (kInputHeight - 20) / 2 ≈ 12
        .padding(.vertical, 12)
        .frame(minHeight: kInputHeight)
        .background(Monolith.background.opacity(0.88), in: RoundedRectangle(cornerRadius: kInputHeight / 2, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: kInputHeight / 2, style: .continuous)
                .strokeBorder(Monolith.ring, lineWidth: 1)
        }
        .focused($inputFocused)
    }

    private var sendButton: some View {
        let canSend = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !session.isResponding
        return Button {
            let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            inputText = ""
            session.stopRecording()
            Task { await session.send(text) }
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Monolith.background)
                .frame(width: kInputHeight, height: kInputHeight)
                .background(Monolith.primary, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(canSend ? 1 : 0.4)
        .disabled(!canSend)
        .accessibilityLabel("Send message")
    }
}

// MARK: - Message Bubbles

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 60)
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(Monolith.background)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Monolith.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .textSelection(.enabled)
            }
        } else {
            AssistantBubble(content: message.content, isStreaming: false)
        }
    }
}

private struct AssistantBubble: View {
    let content: String
    let isStreaming: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(BudgetChatMarkdown.attributedString(from: content))
                    .font(.subheadline)
                    .foregroundStyle(Monolith.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Monolith.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Monolith.hairline, lineWidth: 1)
                    }
                    .textSelection(.enabled)

                if isStreaming {
                    StreamingCursor()
                        .padding(.leading, 14)
                }
            }

            Spacer(minLength: 40)
        }
    }
}

private struct StreamingCursor: View {
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Monolith.primary)
            .frame(width: 2, height: 12)
            .opacity(visible ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

private struct TypingBubble: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .frame(width: 7, height: 7)
                        .foregroundStyle(Monolith.tertiary)
                        .offset(y: animating ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Monolith.hairline, lineWidth: 1)
            }
            .onAppear { animating = true }

            Spacer(minLength: 40)
        }
    }
}

// MARK: - Avatar

private struct TechBroAvatar: View {
    let size: CGFloat

    var body: some View {
        Image("TechBroFace")
            .resizable()
            .scaledToFit()
            .padding(size * 0.1)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Monolith.ring, lineWidth: 1))
    }
}

// MARK: - Background

private struct ChatBackground: View {
    var body: some View {
        BudgetBackground()
    }
}
