import Foundation
import Translation

final class TranslationService {
    private var sessionStorage: Any?
    private var lastTask: Task<Void, Never>?

    func configure(source: Locale.Language?, target: Locale.Language?) {
        guard #available(iOS 18.0, *), let source, let target else {
            sessionStorage = nil
            return
        }
        let config = TranslationSession.Configuration(source: source, target: target)
        sessionStorage = TranslationSession(configuration: config)
    }

    func translate(_ text: String, onResult: @escaping (String?) -> Void) {
        lastTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            onResult(nil)
            return
        }

        guard #available(iOS 18.0, *), let session = sessionStorage as? TranslationSession else {
            onResult(trimmed)
            return
        }

        lastTask = Task {
            do {
                let response = try await session.translate(trimmed)
                guard !Task.isCancelled else { return }
                await MainActor.run { onResult(response.targetText) }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { onResult(nil) }
            }
        }
    }

    func cancel() {
        lastTask?.cancel()
        lastTask = nil
    }
}
