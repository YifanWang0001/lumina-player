import SwiftUI

struct HomeParserView: View {
    @State private var urlText = ""
    let navigate: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            centerContent
        }
        .background(LuminaColor.background)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        Text("Lumina Player")
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(LuminaColor.onSurface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(LuminaColor.outlineVariant).frame(height: 1)
            }
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Text("Lumina Player")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(LuminaColor.onSurface)

                Text("输入链接以提取视频")
                    .font(.system(size: 16))
                    .foregroundColor(LuminaColor.onSurfaceVariant)
            }

            // Form
            VStack(spacing: 16) {
                // URL Input
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundColor(LuminaColor.onSurfaceVariant)
                        .font(.system(size: 16))
                    TextField("输入链接...", text: $urlText)
                        .font(.system(size: 14))
                        .foregroundColor(LuminaColor.onSurface)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .luminaInput()

                // Parse Button
                Button {
                    let trimmed = urlText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        navigate(trimmed)
                    }
                } label: {
                    Text("解析")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LuminaColor.onSurface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LuminaColor.primary)
                        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.button))
                }

                // Local File Button
                Button {
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 14))
                        Text("选择本地视频")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(LuminaColor.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: LuminaRadius.button)
                            .stroke(LuminaColor.outlineVariant, lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: 400)

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}
