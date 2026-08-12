import Foundation
import SwiftUI

@MainActor
final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()

    @Published var lines: [String] = []
    private let maxLines = 200
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    nonisolated func log(_ msg: String) {
        let ts = formatter.string(from: Date())
        let line = "[\(ts)] \(msg)"
        Task { @MainActor in
            DebugLogger.shared.lines.append(line)
            if DebugLogger.shared.lines.count > DebugLogger.shared.maxLines {
                DebugLogger.shared.lines.removeFirst(DebugLogger.shared.lines.count - DebugLogger.shared.maxLines)
            }
        }
    }
}

struct DebugOverlay: View {
    @StateObject private var logger = DebugLogger.shared
    @State private var expanded = false

    var body: some View {
        VStack {
            Spacer()
            if expanded {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(logger.lines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(8)
                        .id("bottom")
                    }
                    .frame(maxHeight: 200)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: logger.lines.count) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }

            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10))
                    Text(expanded ? "收起日志" : "日志 (\(logger.lines.count))")
                        .font(.system(size: 10))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
            }
            .padding(.bottom, 4)
        }
    }
}
