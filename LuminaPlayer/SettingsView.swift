import SwiftUI

enum SettingsTab: String, CaseIterable {
    case translation = "翻译"
    case interface = "界面"
    case voiceModel = "语音模型"
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .translation

    var body: some View {
        VStack(spacing: 0) {
            topBar
            tabSelector
            ScrollView {
                content
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 80)
            }
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

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: selectedTab == tab ? .medium : .regular))
                        .foregroundColor(selectedTab == tab ? LuminaColor.primary : LuminaColor.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selectedTab == tab ? LuminaColor.primary : Color.clear)
                                .frame(height: 2)
                        }
                }
            }
        }
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LuminaColor.outlineVariant).frame(height: 1)
        }
    }

    // MARK: - Settings Title

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(LuminaColor.onSurface)
                .padding(.bottom, 24)

            switch selectedTab {
            case .translation:
                TranslationSettingsContent()
            case .interface:
                InterfaceSettingsContent()
            case .voiceModel:
                VoiceModelSettingsContent()
            }
        }
        .frame(maxWidth: 800)
    }
}

// MARK: - Language option types

enum VideoLanguage: String, CaseIterable {
    case japanese = "日文"
    case chinese = "中文"
    case english = "英文"
    case korean = "韩文"
}

enum TranslationLanguage: String, CaseIterable {
    case chinese = "中文"
    case english = "英文"
    case japanese = "日文"
    case korean = "韩文"
}

enum DisplayMode: String, CaseIterable {
    case bilingual = "双语"
    case translatedOnly = "翻译后语言"
}

// MARK: - Translation Settings

struct TranslationSettingsContent: View {
    @State private var videoLanguage: VideoLanguage = .japanese
    @State private var translationLanguage: TranslationLanguage = .chinese
    @State private var displayMode: DisplayMode = .bilingual

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("视频语音语言")

            VStack(spacing: 0) {
                pickerRow("视频语音语言", selection: $videoLanguage)
                divider
                pickerRow("翻译语言", selection: $translationLanguage)
                divider
                pickerRow("翻译显示", selection: $displayMode)
            }
            .luminaCard()
        }
    }

    private var divider: some View {
        Rectangle().fill(LuminaColor.border).frame(height: 1)
    }

    private func pickerRow<T: Hashable & RawRepresentable>(_ title: String, selection: Binding<T>) -> some View where T.RawValue == String {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(LuminaColor.onSurface)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(LuminaColor.onSurfaceVariant)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .medium))
            .tracking(0.6)
            .foregroundColor(LuminaColor.onSurfaceVariant)
    }
}

// MARK: - Subtitle color options

enum SubtitleColorOption: String, CaseIterable {
    case white = "白色"
    case black = "黑色"
}

enum BackgroundColorOption: String, CaseIterable {
    case black = "黑色"
    case white = "白色"
}

// MARK: - Interface Settings

struct InterfaceSettingsContent: View {
    @State private var subtitleSize: Int = 18
    @State private var backgroundOpacity: Double = 0.5
    @State private var keepScreenOn = true
    @State private var subtitleColor: SubtitleColorOption = .white
    @State private var backgroundColor: BackgroundColorOption = .black

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Subtitle Settings
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("字幕设置")

                VStack(spacing: 0) {
                    colorPickerRow("字幕颜色", selection: $subtitleColor, color: subtitleColor.displayColor)
                    divider
                    sizeRow
                    divider
                    colorPickerRow("背景颜色", selection: $backgroundColor, color: backgroundColor.displayColor)
                    divider
                    settingRow("字幕位置", value: nil)
                    divider
                    opacityRow
                }
                .luminaCard()
            }

            // Screen Settings
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("屏幕设置")

                VStack(spacing: 0) {
                    toggleRow("保持屏幕常亮", isOn: $keepScreenOn)
                }
                .luminaCard()
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(LuminaColor.border).frame(height: 1)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .medium))
            .tracking(0.6)
            .foregroundColor(LuminaColor.onSurfaceVariant)
            .padding(.leading, 8)
    }

    private func settingRow(_ title: String, value: String?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(LuminaColor.onSurface)
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(LuminaColor.onSurfaceVariant)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(LuminaColor.onSurfaceVariant)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func colorPickerRow<T: Hashable & RawRepresentable>(_ title: String, selection: Binding<T>, color: Color) -> some View where T.RawValue == String {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(LuminaColor.onSurface)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(LuminaColor.onSurfaceVariant)
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(LuminaColor.border, lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var sizeRow: some View {
        HStack {
            Text("字幕大小")
                .font(.system(size: 14))
                .foregroundColor(LuminaColor.onSurface)
            Spacer()
            HStack(spacing: 0) {
                Button { if subtitleSize > 10 { subtitleSize -= 1 } } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14))
                        .foregroundColor(LuminaColor.primary)
                        .frame(width: 36, height: 32)
                }
                Text("\(subtitleSize)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LuminaColor.onSurface)
                    .frame(minWidth: 28)
                Button { if subtitleSize < 48 { subtitleSize += 1 } } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(LuminaColor.primary)
                        .frame(width: 36, height: 32)
                }
            }
            .background(LuminaColor.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var opacityRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("背景不透明度")
                    .font(.system(size: 14))
                    .foregroundColor(LuminaColor.onSurface)
                Spacer()
                Text("\(Int(backgroundOpacity * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LuminaColor.primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LuminaColor.surfaceContainer)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(LuminaColor.primary)
                        .frame(width: geo.size.width * backgroundOpacity, height: 4)

                    Circle()
                        .fill(LuminaColor.onSurface)
                        .frame(width: 14, height: 14)
                        .offset(x: geo.size.width * backgroundOpacity - 7)
                }
                .frame(height: 14)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = min(max(value.location.x / geo.size.width, 0), 1)
                            backgroundOpacity = Double(ratio)
                        }
                )
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(LuminaColor.onSurface)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(LuminaColor.primary)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Color helpers

extension SubtitleColorOption {
    var displayColor: Color {
        switch self {
        case .white: .white
        case .black: .black
        }
    }
}

extension BackgroundColorOption {
    var displayColor: Color {
        switch self {
        case .black: .black
        case .white: .white
        }
    }
}

// MARK: - Voice Model Settings

struct VoiceModelSettingsContent: View {
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("系统语言模型")

            VStack(spacing: 0) {
                Button {
                    withAnimation { expanded.toggle() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default System Voice")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(LuminaColor.onSurface)
                        }
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(LuminaColor.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                if expanded {
                    Rectangle().fill(LuminaColor.border).frame(height: 1)
                    Text("选择播放期间用于文本转语音渲染的基础引擎。")
                        .font(.system(size: 12))
                        .foregroundColor(LuminaColor.onSurfaceVariant)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .luminaCard()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .medium))
            .tracking(0.6)
            .foregroundColor(LuminaColor.onSurfaceVariant)
            .padding(.leading, 8)
    }
}
