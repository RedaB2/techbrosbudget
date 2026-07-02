//
//  BudgetChatSession.swift
//  techbrosbudget
//

import Foundation
import FoundationModels
import Speech
import AVFoundation
import Observation
import os

struct ChatMessage: Identifiable, Equatable {
    var id = UUID()
    var role: Role
    var content: String

    enum Role: Equatable {
        case user
        case assistant
    }
}

@Observable
@MainActor
final class BudgetChatSession {
    private static let logger = Logger(subsystem: "reda.techbrosbudget", category: "BudgetChat")

    var messages: [ChatMessage] = []
    var isResponding = false
    var streamingContent: String = ""
    var isRecording = false
    var liveTranscription: String = ""

    private var languageSession: LanguageModelSession?
    private var audioEngine = AVAudioEngine()
    private var tapInstalled = false
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()

    var isModelAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func open(store: BudgetStore) {
        messages = []
        streamingContent = ""
        liveTranscription = ""
        languageSession = nil

        if let seededMessage = Self.uiTestSeededMessage {
            messages.append(ChatMessage(role: .assistant, content: seededMessage))
            return
        }

        guard isModelAvailable else { return }

        languageSession = LanguageModelSession(instructions: Self.instructions(for: store))
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: trimmed))
        isResponding = true
        streamingContent = ""
        defer {
            isResponding = false
            streamingContent = ""
        }

        guard let languageSession, isModelAvailable else {
            messages.append(ChatMessage(
                role: .assistant,
                content: "Apple Intelligence isn't available on this device. Enable it in Settings → Apple Intelligence & Siri to get personalized budget insights."
            ))
            return
        }

        do {
            let reply = try await streamReply(from: languageSession, to: trimmed)
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch {
            Self.logger.error("Chat generation failed: \(error, privacy: .public)")

            // On some iOS 26 builds the system safety classifier fails to load
            // and every request throws even though the language model works
            // (see FoundationModelsFailure). Retry once with relaxed
            // guardrails and keep that session for the rest of the chat.
            if FoundationModelsFailure.isSafetyModelFailure(error),
               let recovered = await retryWithRelaxedGuardrails(after: languageSession, prompt: trimmed) {
                messages.append(ChatMessage(role: .assistant, content: recovered))
            } else {
                messages.append(ChatMessage(
                    role: .assistant,
                    content: "Something went wrong generating a response. Please try again."
                ))
            }
        }
    }

    private func streamReply(from session: LanguageModelSession, to prompt: String) async throws -> String {
        let stream = session.streamResponse(to: prompt)
        var accumulated = ""
        for try await snapshot in stream {
            accumulated = snapshot.content
            streamingContent = accumulated
        }
        return accumulated
    }

    private func retryWithRelaxedGuardrails(after failed: LanguageModelSession, prompt: String) async -> String? {
        var entries = Array(failed.transcript)
        if let last = entries.last, case .prompt = last {
            entries.removeLast()
        }

        let relaxed = LanguageModelSession(
            model: SystemLanguageModel(guardrails: .permissiveContentTransformations),
            transcript: Transcript(entries: entries)
        )

        do {
            let reply = try await streamReply(from: relaxed, to: prompt)
            languageSession = relaxed
            return reply
        } catch {
            Self.logger.error("Relaxed-guardrails retry failed: \(error, privacy: .public)")
            return nil
        }
    }

    func startRecording() async {
        guard await AVCaptureDevice.requestAccess(for: .audio) else { return }

        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized, let speechRecognizer else { return }

        stopRecording()

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        self.liveTranscription = result.bestTranscription.formattedString
                    }
                    if error != nil || result?.isFinal == true {
                        self.stopRecording()
                    }
                }
            }

            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            tapInstalled = true

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            liveTranscription = ""
        } catch {
            stopRecording()
        }
    }

    func stopRecording() {
        audioEngine.stop()
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    static func instructions(for store: BudgetStore) -> String {
        """
        You are "Tech Bro", the budget advisor mascot for Tech Bros Budget. Keep the name, but speak like a casual, friendly budget coach.
        Do not use fratty slang, hype slang, roasting, macho tone, or repeated catchphrases. Do not call the user "bro".
        Help the user understand their spending, identify where they are overspending, and suggest specific ways to cut costs.
        The day, week, and month totals below are amounts already spent, not budget limits or target budgets. Treat them as actual spending totals unless the user explicitly gives you a budget.
        Use the actual numbers from their data. Keep responses to 2-3 short, useful paragraphs.
        You may use lightweight Markdown for emphasis, including **bold**, *italic*, and short lists. Do not use em dashes.

        \(budgetContext(for: store))
        """
    }

    private static var uiTestSeededMessage: String? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("UITEST_MARKDOWN_CHAT") else {
            return nil
        }
        return "Markdown check: **bold spending**, *friendly tone*, and `daily spent`."
        #else
        return nil
        #endif
    }

    private static func budgetContext(for store: BudgetStore) -> String {
        var lines = ["Current spending snapshot. These are spent amounts, not budget limits:"]
        lines.append("- Spent today: \(MoneyFormatter.currency(store.total(for: .day)))")
        lines.append("- Spent this week: \(MoneyFormatter.currency(store.total(for: .week)))")
        lines.append("- Spent this month: \(MoneyFormatter.currency(store.total(for: .month)))")

        let categories = store.categoryTotals(for: .month)
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
        if !categories.isEmpty {
            lines.append("\nTop spending categories this month:")
            for (category, total) in categories.prefix(6) {
                lines.append("  \(category.rawValue): \(MoneyFormatter.currency(total))")
            }
        }

        let recent = store.expenses.prefix(6)
        if !recent.isEmpty {
            lines.append("\nMost recent transactions:")
            for expense in recent {
                lines.append("  \(MoneyFormatter.currency(expense.amount)) - \(expense.note) [\(expense.category.rawValue)]")
            }
        }

        return lines.joined(separator: "\n")
    }
}
