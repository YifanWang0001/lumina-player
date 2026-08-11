import Foundation
import Translation

@available(iOS 17.4, *)
final class TranslationService {
    private var lastTask: Task<Void, Never>?

    func translate(_ text: String, onResult: @escaping (String?) -> Void) {
        lastTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            onResult(nil)
            return
        }

        lastTask = Task {
            do {
                let availability = LanguageAvailability()
                let status = await availability.status(from: .japanese, to: .chinese)

                guard status == .installed else {
                    guard !Task.isCancelled else { return }
                    onResult("[Translation model needs download]")
                    return
                }

                let session = TranslationSession(
                    sourceLanguage: .japanese,
                    targetLanguage: .chinese
                )

                let response = try await session.translate(trimmed)

                guard !Task.isCancelled else { return }
                onResult(response.targetText)
            } catch {
                guard !Task.isCancelled else { return }
                onResult(nil)
            }
        }
    }

    func cancel() {
        lastTask?.cancel()
        lastTask = nil
    }
}
