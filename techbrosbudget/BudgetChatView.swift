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

            VStack(alignment: .leading, spacing: 2) {
                Text("Tech Bro")
                    .font(.headline)
                Text("Your budget advisor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: kInputHeight, height: kInputHeight)
            }
            .buttonStyle(.glass)
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

    private var welcomeBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            TechBroAvatar(size: 30)

            VStack(alignment: .leading, spacing: 6) {
                Text(session.isModelAvailable ? "Yo! I'm Tech Bro 👋" : "Not Available")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(session.isModelAvailable ? Color.primary : Color.orange)

                Text(
                    session.isModelAvailable
                    ? "What's your budget situation looking like? Ask me anything — biggest spends, where to cut costs, category breakdowns, whatever you need."
                    : "Apple Intelligence isn't enabled. Head to Settings → Apple Intelligence & Siri to turn it on."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 40)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
    }

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
            Image(systemName: session.isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(session.isRecording ? .red : .primary)
                .frame(width: kInputHeight, height: kInputHeight)
        }
        .buttonStyle(.glass)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: kInputHeight / 2, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: kInputHeight / 2, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
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
                .font(.system(size: 17, weight: .bold))
                .frame(width: kInputHeight, height: kInputHeight)
        }
        .buttonStyle(.glassProminent)
        .opacity(canSend ? 1 : 0.45)
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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.teal.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            TechBroAvatar(size: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
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
            .fill(Color.teal)
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
            TechBroAvatar(size: 28)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .frame(width: 7, height: 7)
                        .foregroundStyle(.secondary)
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear { animating = true }

            Spacer(minLength: 40)
        }
    }
}

// MARK: - Avatar

private struct TechBroAvatar: View {
    let size: CGFloat

    var body: some View {
        Image("BrandLogoForeground")
            .resizable()
            .scaledToFit()
            .padding(size * 0.1)
            .frame(width: size, height: size)
            .background(Color.teal.opacity(0.12), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - Background

private struct ChatBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Color(.systemBackground)
            if !reduceTransparency {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.teal.opacity(0.1), Color.indigo.opacity(0.08), Color(.systemBackground)]
                        : [Color.teal.opacity(0.07), Color.mint.opacity(0.09), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}
