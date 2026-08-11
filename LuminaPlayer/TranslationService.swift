import Foundation

final class TranslationService {
    private var lastTask: Task<Void, Never>?

    func configure(source: Locale.Language?, target: Locale.Language?) {
        // TranslationSession is only available through SwiftUI's .translationTask()
        // modifier and cannot be instantiated directly. For now, pass through.
        // TODO: integrate .translationTask or use alternative translation backend.
    }

    func translate(_ text: String, onResult: @escaping (String?) -> Void) {
        lastTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            onResult(nil)
            return
        }

        onResult(trimmed)
    }

    func cancel() {
        lastTask?.cancel()
        lastTask = nil
    }
}
