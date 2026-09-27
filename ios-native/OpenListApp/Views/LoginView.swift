import SwiftUI

/// 登录页:全部使用系统组件(Form/TextField/系统按钮),
/// 液态玻璃完全由 iOS 26 系统渲染。
struct LoginView: View {
    @Environment(AppState.self) private var app
    @State private var serverURL = ""
    @State private var username = "admin"
    @State private var password = ""
    @State private var busy = false
    @State private var errorText: String?
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case server, username, password
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("服务器") {
                    TextField("服务器地址", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .server)
                        .onSubmit { focused = .username }
                }

                Section("账号") {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .username)
                        .onSubmit { focused = .password }
                    SecureField("密码", text: $password)
                        .focused($focused, equals: .password)
                        .onSubmit { Task { await signIn() } }
                }

                Section {
                    Button {
                        Task { await signIn() }
                    } label: {
                        HStack {
                            Spacer()
                            if busy {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("登录")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .listRowBackground(Color.clear)
                    .disabled(busy)

                    Button {
                        Task { await skipLogin() }
                    } label: {
                        HStack {
                            Spacer()
                            Text("跳过登录")
                            Spacer()
                        }
                    }
                    .buttonStyle(.glass)
                    .listRowBackground(Color.clear)
                    .disabled(busy)
                }
            }
            .navigationTitle("OpenList")
            .onAppear {
                if serverURL.isEmpty {
                    serverURL = app.baseURL
                }
            }
            .errorAlert($errorText)
        }
    }

    private func signIn() async {
        focused = nil
        let base = APIClient.normalizedBaseURL(serverURL)
        guard !base.isEmpty, !username.isEmpty, !password.isEmpty else {
            errorText = "请填写服务器地址、用户名和密码"
            return
        }
        busy = true
        defer { busy = false }
        let api = APIClient(baseURL: base)
        do {
            let token = try await api.login(username: username, password: password)
            var name = username
            if let me = try? await APIClient(baseURL: base, token: token).me() {
                name = me.username ?? username
            }
            app.signIn(baseURL: base, token: token, username: name)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func skipLogin() async {
        let base = APIClient.normalizedBaseURL(serverURL)
        guard !base.isEmpty else {
            errorText = "请先填写服务器地址"
            return
        }
        // 访客模式:空 token。
        app.signIn(baseURL: base, token: "", username: "")
    }
}
