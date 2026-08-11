import Foundation
import Translation

final class TranslationService {
    private var session: TranslationSession?
    private var lastTask: Task<Void, Never>?

    func configure(source: Locale.Language?, target: Locale.Language?) {
        guard let source, let target else {
            session = nil
            return
        }
        let config = TranslationSession.Configuration(source: source, target: target)
        session = TranslationSession(configuration: config)
    }

    func translate(_ text: String, onResult: @escaping (String?) -> Void) {
        lastTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            onResult(nil)
            return
        }

        guard let session else {
            onResult(nil)
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
