import SwiftUI

/// 任务页:未登录显示空态不请求;连接失败显示页内错误态 + 重试。
struct TasksView: View {
    @Environment(AppState.self) private var app
    @State private var segment = 0
    @State private var tasks: [TaskItem] = []
    @State private var loading = false
    @State private var loadError: String?

    private var api: APIClient {
        APIClient(baseURL: app.baseURL, token: app.token)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Picker("任务类型", selection: $segment) {
                    Text("未完成").tag(0)
                    Text("已完成").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                content
            }
            .padding(.top, 8)
            .navigationTitle("任务")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await load() }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await load() }
            .task(id: segment) { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !app.hasToken {
            loginRequired
        } else if loading && tasks.isEmpty {
            ProgressView()
        } else if let loadError, tasks.isEmpty {
            unavailable(message: loadError)
        } else if tasks.isEmpty {
            ContentUnavailableView(
                segment == 0 ? "没有未完成任务" : "没有已完成任务",
                systemImage: "checkmark.circle"
            )
        } else {
            taskList
        }
    }

    private var loginRequired: some View {
        ContentUnavailableView {
            Label("请先登录", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text("任务管理需要登录服务器账号")
        } actions: {
            Button("去登录") {
                app.signOut()
            }
            .buttonStyle(.glassProminent)
        }
    }

    private func unavailable(message: String) -> some View {
        ContentUnavailableView {
            Label("无法连接服务器", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("重试") {
                Task { await load() }
            }
            .buttonStyle(.glassProminent)
        }
    }

    private var taskList: some View {
        List {
            ForEach(tasks) { task in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(task.displayName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                        Spacer()
                        Text(task.displayState)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(stateColor(task))
                    }
                    ProgressView(value: task.progressFraction)
                        .tint(stateColor(task))
                    HStack {
                        Spacer()
                        Text("\(Int(task.progressFraction * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func stateColor(_ task: TaskItem) -> Color {
        switch task.displayState {
        case "running": return .blue
        case "succeed": return .green
        case "errored", "failed", "canceled": return .red
        default: return .orange
        }
    }

    private func load() async {
        guard app.hasToken else { return }
        loading = true
        defer { loading = false }
        do {
            tasks = try await api.tasks(undone: segment == 0)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}
