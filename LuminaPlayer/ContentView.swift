import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "主页"
    case settings = "设置"
    case my = "我的"

    var icon: String {
        switch self {
        case .home: "house"
        case .settings: "gearshape"
        case .my: "person"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var homePath = NavigationPath()

    var body: some View {
        ZStack(alignment: .bottom) {
            LuminaColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                switch selectedTab {
                case .home:
                    NavigationStack(path: $homePath) {
                        HomeParserView(navigate: { url in homePath.append(url) })
                            .navigationDestination(for: String.self) { url in
                                HomePlayerView(url: url, goBack: { homePath.removeLast() })
                                    .navigationBarHidden(true)
                            }
                    }
                case .settings:
                    SettingsView()
                case .my:
                    MyView()
                }

                bottomBar
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                    if tab == .home { homePath = NavigationPath() }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(LuminaColor.primary.opacity(0.15))
                                    .frame(width: 56, height: 32)
                            }
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                                .symbolVariant(selectedTab == tab ? .fill : .none)
                        }
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: selectedTab == tab ? .medium : .regular))
                    }
                    .foregroundColor(selectedTab == tab ? LuminaColor.primary : LuminaColor.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 64)
        .padding(.horizontal, 24)
        .background(LuminaColor.surfaceContainerLowest)
        .overlay(alignment: .top) {
            Rectangle().fill(LuminaColor.border).frame(height: 1)
        }
    }
}
