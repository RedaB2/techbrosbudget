//
//  BudgetChatSession.swift
//  techbrosbudget
//

import Foundation
import FoundationModels
import Speech
import AVFoundation
import Observation

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

        guard isModelAvailable else { return }

        languageSession = LanguageModelSession(
            instructions: """
            You are a friendly, concise budget advisor inside a personal expense tracker called TechBros Budget.
            Help the user understand their spending patterns, suggest ways to save money, and answer questions about specific categories.
            Use the actual numbers from their data when giving advice. Keep responses to 2-3 short paragraphs. Be direct and conversational.

            \(budgetContext(for: store))
            """
        )
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
            let stream = languageSession.streamResponse(to: trimmed)
            var accumulated = ""
            for try await snapshot in stream {
                accumulated = snapshot.content
                streamingContent = accumulated
            }
            messages.append(ChatMessage(role: .assistant, content: accumulated))
        } catch {
            messages.append(ChatMessage(
                role: .assistant,
                content: "Something went wrong generating a response. Please try again."
            ))
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

    private func budgetContext(for store: BudgetStore) -> String {
        var lines = ["Current budget snapshot:"]
        lines.append("- Today: \(MoneyFormatter.currency(store.total(for: .day)))")
        lines.append("- This week: \(MoneyFormatter.currency(store.total(for: .week)))")
        lines.append("- This month: \(MoneyFormatter.currency(store.total(for: .month)))")

        let categories = store.categoryTotals(for: .month)
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
        if !categories.isEmpty {
            lines.append("\nTop categories this month:")
            for (category, total) in categories.prefix(6) {
                lines.append("  \(category.rawValue): \(MoneyFormatter.currency(total))")
            }
        }

        let recent = store.expenses.prefix(6)
        if !recent.isEmpty {
            lines.append("\nMost recent transactions:")
            for expense in recent {
                lines.append("  \(MoneyFormatter.currency(expense.amount)) — \(expense.note) [\(expense.category.rawValue)]")
            }
        }

        return lines.joined(separator: "\n")
    }
}
