import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case transport(String)
    case http(Int)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "服务器地址无效"
        case .transport(let message):
            return "网络错误:\(message)"
        case .http(let code):
            return "HTTP \(code)"
        case .server(let message):
            return message
        }
    }
}

/// OpenList/AList HTTP API 客户端(async/await + URLSession)。
struct APIClient {
    var baseURL: String
    var token: String?

    /// 归一化:去掉末尾斜杠;无协议时补 http://。
    static func normalizedBaseURL(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return value }
        if !value.contains("://") {
            value = "http://" + value
        }
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    private var root: String {
        Self.normalizedBaseURL(baseURL)
    }

    private func makeRequest(_ method: String, _ path: String, json: [String: Any]? = nil) throws -> URLRequest {
        guard let url = URL(string: root + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        if let token, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        if json != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let json {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        return request
    }

    /// 发送请求并解码 data 字段;data 为 null 时返回 nil。
    private func send<T: Decodable>(_ method: String, _ path: String, json: [String: Any]? = nil) async throws -> T? {
        let request = try makeRequest(method, path, json: json)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.http(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard decoded.code == 200 else {
            throw APIError.server(decoded.message ?? "API error \(decoded.code)")
        }
        return decoded.data
    }

    // MARK: 认证

    func login(username: String, password: String) async throws -> String {
        let data: LoginData? = try await send(
            "POST", "/api/auth/login",
            json: ["username": username, "password": password]
        )
        guard let token = data?.token, !token.isEmpty else {
            throw APIError.server("登录失败:未返回 token")
        }
        return token
    }

    func me() async throws -> MeData? {
        try await send("GET", "/api/me")
    }

    func publicSettings() async throws -> PublicSettings? {
        try await send("GET", "/api/public/settings")
    }

    // MARK: 存储

    func storages() async throws -> [Storage] {
        let data: StorageListData? = try await send("GET", "/api/admin/storage/list")
        return data?.content ?? []
    }

    func driverList() async throws -> [String: DriverInfo] {
        let data: [String: DriverInfo]? = try await send("GET", "/api/admin/driver/list")
        return data ?? [:]
    }

    func createStorage(_ payload: [String: Any]) async throws {
        let _: EmptyData? = try await send("POST", "/api/admin/storage/create", json: payload)
    }

    func setStorageEnabled(_ enable: Bool, id: Int) async throws {
        let op = enable ? "enable" : "disable"
        let _: EmptyData? = try await send("POST", "/api/admin/storage/\(op)?id=\(id)")
    }

    func deleteStorage(id: Int) async throws {
        let _: EmptyData? = try await send("POST", "/api/admin/storage/delete?id=\(id)")
    }

    // MARK: 文件

    func listFiles(path: String) async throws -> [FileEntry] {
        let data: FsListData? = try await send("POST", "/api/fs/list", json: ["path": path])
        return data?.content ?? []
    }

    func fileGet(path: String) async throws -> FsGetData? {
        try await send("POST", "/api/fs/get", json: ["path": path, "password": ""])
    }

    func removeFiles(dir: String, names: [String]) async throws {
        let _: EmptyData? = try await send("POST", "/api/fs/remove", json: ["dir": dir, "names": names])
    }

    /// 文件直链(优先 raw_url,失败时回退 /d 直链并携带 Authorization)。
    func downloadURL(path: String) async -> URL? {
        if let raw = (try? await fileGet(path: path))??.raw_url, let url = URL(string: raw) {
            return url
        }
        return URL(string: root + "/d" + path)
    }

    // MARK: 任务

    func tasks(undone: Bool) async throws -> [TaskItem] {
        let path = undone ? "/api/admin/task/undone" : "/api/admin/task/done"
        let payload: TaskPayload? = try await send("GET", path)
        return payload?.items ?? []
    }
}
