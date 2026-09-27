import SwiftUI

/// 根界面:四个原生标签页;滚动时标签栏自动最小化为玻璃圆点(iOS 26)。
struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("存储", systemImage: "internaldrive.fill") {
                StoragesView()
            }
            Tab("文件", systemImage: "folder.fill") {
                FilesView()
            }
            Tab("任务", systemImage: "checkmark.circle.fill") {
                TasksView()
            }
            Tab("我的", systemImage: "person.fill") {
                ProfileView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
