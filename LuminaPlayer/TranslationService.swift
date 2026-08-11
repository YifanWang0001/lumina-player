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
                let session = TranslationSession()
                let response = try await session.translate(trimmed)

                guard !Task.isCancelled else { return }
                onResult(response.targetText)
            } catch {
                guard !Task.isCancelled else { return }
                onResult("[Translation unavailable: \(error.localizedDescription)]")
            }
        }
    }

    func cancel() {
        lastTask?.cancel()
        lastTask = nil
    }
}
