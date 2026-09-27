import SwiftUI

/// 我的:用户信息 + 原生服务器设置 + 登录/退出。
struct ProfileView: View {
    @Environment(AppState.self) private var app
    @State private var serverVersion: String?
    @State private var showServerSettings = false

    private var api: APIClient {
        APIClient(baseURL: app.baseURL, token: app.token)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("用户", value: app.hasToken ? (app.username.isEmpty ? "已登录" : app.username) : "访客模式")
                    LabeledContent("服务器", value: app.baseURL)
                    LabeledContent("版本", value: serverVersion ?? "…")
                    Button {
                        showServerSettings = true
                    } label: {
                        Label("服务器设置", systemImage: "network")
                    }
                } header: {
                    Text("服务器")
                }

                Section {
                    Button(role: app.hasToken ? .destructive : nil) {
                        app.signOut()
                    } label: {
                        Label(app.hasToken ? "退出登录" : "去登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
            .task {
                if let settings = try? await api.publicSettings() {
                    serverVersion = settings.version
                }
            }
            .sheet(isPresented: $showServerSettings) {
                ServerSettingsSheet()
            }
        }
    }
}

/// 原生服务器设置:修改目标服务器地址。
struct ServerSettingsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://127.0.0.1:5244", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("修改后立即生效,客户端会连接新的服务器。")
                }
            }
            .navigationTitle("服务器设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let normalized = APIClient.normalizedBaseURL(url)
                        if !normalized.isEmpty {
                            app.baseURL = normalized
                        }
                        dismiss()
                    }
                }
            }
            .onAppear { url = app.baseURL }
        }
        .presentationDetents([.medium])
    }
}
