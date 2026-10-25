import SwiftUI

struct RootView: View {
    enum Tab: Hashable { case learn, chat, explore, review, profile }

    @EnvironmentObject private var progress: ProgressStore
    @State private var tab: Tab = .learn

    var body: some View {
        if let error = CourseStore.shared.loadError {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.vBad)
                Text(error)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else {
            TabView(selection: $tab) {
                PathView(tab: $tab)
                    .tabItem { Label("学习", systemImage: "map.fill") }
                    .tag(Tab.learn)

                ChatHomeView()
                    .tabItem { Label("对话", systemImage: "bubble.left.and.bubble.right.fill") }
                    .tag(Tab.chat)

                ToolsView()
                    .tabItem { Label("探索", systemImage: "safari.fill") }
                    .tag(Tab.explore)

                ReviewHomeView()
                    .tabItem { Label("复习", systemImage: "rectangle.stack.fill") }
                    .badge(progress.dueCount)
                    .tag(Tab.review)

                ProfileView()
                    .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
                    .tag(Tab.profile)
            }
        }
    }
}
