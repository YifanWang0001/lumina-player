import Foundation

final class TranslationService {
    private var lastTask: Task<Void, Never>?
    private var sourceLang = "ja"
    private var targetLang = "zh-CN"

    func configure(source: Locale.Language?, target: Locale.Language?) {
        if let source {
            sourceLang = mapToGoogleCode(source)
        }
        if let target {
            targetLang = mapToGoogleCode(target)
        }
    }

    private func mapToGoogleCode(_ lang: Locale.Language) -> String {
        let id = lang.maximalIdentifier
        if id.hasPrefix("ja") { return "ja" }
        if id.hasPrefix("zh-Hans") || id.hasPrefix("zh-CN") { return "zh-CN" }
        if id.hasPrefix("zh") { return "zh-CN" }
        if id.hasPrefix("ko") { return "ko" }
        if id.hasPrefix("en") { return "en" }
        return "ja"
    }

    func translate(_ text: String, onResult: @escaping (String?) -> Void) {
        lastTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            onResult(nil)
            return
        }

        lastTask = Task {
            var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
            components.queryItems = [
                URLQueryItem(name: "client", value: "gtx"),
                URLQueryItem(name: "sl", value: sourceLang),
                URLQueryItem(name: "tl", value: targetLang),
                URLQueryItem(name: "dt", value: "t"),
                URLQueryItem(name: "q", value: trimmed),
            ]

            guard let url = components.url else {
                onResult(nil)
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }

                if let result = parseResponse(data) {
                    await MainActor.run { onResult(result) }
                } else {
                    await MainActor.run { onResult(nil) }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { onResult(nil) }
            }
        }
    }

    private func parseResponse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let first = json.first as? [Any],
              !first.isEmpty else { return nil }

        var result = ""
        for item in first {
            guard let segment = item as? [Any], let text = segment.first as? String else { continue }
            result += text
        }
        return result.isEmpty ? nil : result
    }

    func cancel() {
        lastTask?.cancel()
        lastTask = nil
    }
}
