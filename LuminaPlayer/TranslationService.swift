import Foundation

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
            // Translation framework not available in CI SDK; pass through for now.
            // TODO: enable when TranslationSession is available in linked SDK.
            guard !Task.isCancelled else { return }
            onResult(trimmed)
        }
    }

    func cancel() {
        lastTask?.cancel()
        lastTask = nil
    }
}
