import Foundation

// MARK: - API 响应

/// OpenList/AList 统一响应结构:{"code":200,"message":"ok","data":...}
struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String?
    let data: T?
}

struct EmptyData: Decodable {}

struct LoginData: Decodable {
    let token: String?
}

struct MeData: Decodable {
    let username: String?
    let base_url: String?
    let role: Int?
}

struct PublicSettings: Decodable {
    let version: String?
    let site_title: String?
}

// MARK: - 存储

struct Storage: Decodable, Identifiable {
    let id: Int
    let mount_path: String?
    let driver: String?
    let status: String?
    let disabled: Bool?
    let remark: String?

    var mountPath: String { mount_path ?? "/" }
    var driverName: String { driver ?? "-" }
    var isDisabled: Bool { disabled ?? false }
    var isWorking: Bool { status == "work" }
}

struct StorageListData: Decodable {
    let content: [Storage]?
    let total: Int?
}

// MARK: - 驱动与字段定义

/// 兼容任意 JSON 标量(字符串/数字/布尔/空)的值。
enum FlexibleValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            self = .null
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .number(let value):
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(value))
                : String(value)
        case .bool(let value): return value ? "true" : "false"
        case .null: return ""
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value): return value
        case .string(let value): return Double(value)
        default: return nil
        }
    }

    var boolValue: Bool {
        switch self {
        case .bool(let value): return value
        case .string(let value): return value == "true" || value == "1"
        case .number(let value): return value != 0
        default: return false
        }
    }
}

struct DriverField: Decodable, Identifiable {
    let name: String
    let type: String?
    let required: Bool?
    let `default`: FlexibleValue?
    let help: String?
    let options: String?

    var id: String { name }
    var isRequired: Bool { required ?? false }
    var fieldType: String { type ?? "string" }
    var selectOptions: [String] {
        (options ?? "").split(separator: ",").map { String($0) }.filter { !$0.isEmpty }
    }
}

struct DriverInfo: Decodable {
    let common: [DriverField]?
    let additional: [DriverField]?
}

// MARK: - 文件

struct FileEntry: Decodable, Identifiable {
    let name: String
    let size: Int64?
    let is_dir: Bool?
    let modified: String?
    // 解码后由视图层补全的完整路径(不参与解码,Optional 缺键安全)。
    var fullPath: String?

    var id: String { name }
    var isDirectory: Bool { is_dir ?? false }
    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }
}

struct FsListData: Decodable {
    let content: [FileEntry]?
    let total: Int?
}

struct FsGetData: Decodable {
    let name: String?
    let raw_url: String?
    let size: Int64?
    let is_dir: Bool?
}

// MARK: - 任务

struct TaskItem: Decodable, Identifiable {
    let id: Int?
    let name: String?
    let state: String?
    let progress: FlexibleValue?

    var displayName: String { name ?? "Task #\(id ?? 0)" }
    var displayState: String {
        let value = state ?? ""
        return value.isEmpty ? "pending" : value
    }
    /// AList 进度取值 0-100。
    var progressFraction: Double {
        let value = progress?.doubleValue ?? 0
        return min(max(value / 100, 0), 1)
    }
}

/// /api/admin/task/* 的 data 可能是 {"copy":[...]} 分组字典,也可能是数组。
struct TaskPayload: Decodable {
    let items: [TaskItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: [TaskItem]].self) {
            items = dict.values.flatMap { $0 }
        } else if let list = try? container.decode([TaskItem].self) {
            items = list
        } else {
            items = []
        }
    }
}
