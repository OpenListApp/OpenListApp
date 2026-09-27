import Foundation
import Observation

/// 全局应用状态:服务器地址、登录令牌、用户名。
/// 使用 iOS 17+ @Observable,SwiftUI 按属性粒度刷新。
@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    private static let defaults = UserDefaults.standard

    var baseURL: String {
        didSet { Self.defaults.set(baseURL, forKey: "openlist.baseURL") }
    }

    var token: String? {
        didSet { Self.defaults.set(token, forKey: "openlist.token") }
    }

    var username: String {
        didSet { Self.defaults.set(username, forKey: "openlist.username") }
    }

    /// 是否已进入主界面。
    /// token 为 nil = 未进入;空字符串 = 访客模式(跳过登录);非空 = 已登录。
    var isSignedIn: Bool {
        token != nil
    }

    /// 是否持有有效登录令牌。
    var hasToken: Bool {
        let value = token ?? ""
        return !value.isEmpty
    }

    init() {
        baseURL = Self.defaults.string(forKey: "openlist.baseURL") ?? "http://127.0.0.1:5244"
        token = Self.defaults.string(forKey: "openlist.token")
        username = Self.defaults.string(forKey: "openlist.username") ?? ""
    }

    func signIn(baseURL: String, token: String, username: String) {
        self.baseURL = baseURL
        self.token = token
        self.username = username
    }

    func signOut() {
        token = nil
        username = ""
    }
}
