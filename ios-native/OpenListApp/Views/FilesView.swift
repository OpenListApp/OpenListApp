import SwiftUI
import UIKit

/// 文件浏览器:List 行 + 导航下钻 + 长按操作;顶部工具栏原生玻璃。
struct FilesView: View {
    var body: some View {
        NavigationStack {
            FilesBrowserView(path: "/")
        }
    }
}

struct FilesBrowserView: View {
    @Environment(AppState.self) private var app
    let path: String

    @State private var entries: [FileEntry] = []
    @State private var loading = false
    @State private var loadError: String?
    @State private var errorText: String?
    @State private var viewerFile: FileEntry?
    @State private var playerFile: RemoteFile?
    @State private var pendingDelete: FileEntry?
    @State private var openFile: FileEntry?

    private var api: APIClient {
        APIClient(baseURL: app.baseURL, token: app.token)
    }

    private static let imageExts: Set<String> = ["bmp", "jpg", "jpeg", "png", "gif", "webp", "ico", "heic"]
    private static let videoExts: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "flv", "rmvb", "webm"]
    private static let audioExts: Set<String> = ["mp3", "wav", "aac", "m4a", "flac", "ogg", "wma", "aiff", "aif", "amr", "m4r"]

    var body: some View {
        Group {
            if loading && entries.isEmpty {
                ProgressView()
            } else if let loadError, entries.isEmpty {
                unavailable(message: loadError)
            } else if entries.isEmpty {
                ContentUnavailableView("空文件夹", systemImage: "folder")
            } else {
                fileList
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
        }
        .navigationDestination(for: String.self) { dir in
            FilesBrowserView(path: dir)
        }
        .refreshable { await load() }
        .task(id: path) { await load() }
        .confirmationDialog(
            "删除 \(pendingDelete?.name ?? "")?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                guard let file = pendingDelete else { return }
                pendingDelete = nil
                Task { await delete(file) }
            }
            Button("取消", role: .cancel) {}
        }
        .fullScreenCover(item: $viewerFile) { file in
            PhotoViewerView(entry: file, api: api)
        }
        .sheet(item: $playerFile) { file in
            VideoPlayerView(url: file.url)
                .presentationDetents([.large])
        }
        .sheet(item: $openFile) { file in
            UnknownFileSheet(path: joinPath(file.name), api: api)
                .presentationDetents([.medium])
        }
        .errorAlert($errorText)
    }

    private var title: String {
        path == "/" ? "文件" : ((path as NSString).lastPathComponent)
    }

    private var fileList: some View {
        List {
            ForEach(entries) { entry in
                row(entry)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func row(_ entry: FileEntry) -> some View {
        let destination: String? = entry.isDirectory ? joinPath(entry.name) : nil
        HStack(spacing: 12) {
            thumbnail(entry)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.body)
                    .lineLimit(2)
                if !entry.isDirectory {
                    Text(ByteCountFormatter.string(fromByteCount: entry.size ?? 0, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if entry.isDirectory {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .background {
            if let destination {
                NavigationLink(value: destination) {
                    EmptyView()
                }
                .opacity(0)
            }
        }
        .contextMenu {
            if !entry.isDirectory {
                Button {
                    Task { await shareOrOpen(entry) }
                } label: {
                    Label("下载 / 打开", systemImage: "arrow.down.circle")
                }
            }
            Button(role: .destructive) {
                pendingDelete = entry
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            if !entry.isDirectory {
                Task { await open(entry) }
            }
        })
    }

    @ViewBuilder
    private func thumbnail(_ entry: FileEntry) -> some View {
        if entry.isDirectory {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 44)
        } else if Self.imageExts.contains(entry.fileExtension) {
            RemoteImageView(path: joinPath(entry.name), api: api)
        } else {
            Image(systemName: iconName(entry))
                .font(.title3)
                .foregroundStyle(iconColor(entry))
                .frame(width: 44)
        }
    }

    private func iconName(_ entry: FileEntry) -> String {
        let ext = entry.fileExtension
        if Self.videoExts.contains(ext) { return "film" }
        if Self.audioExts.contains(ext) { return "music.note" }
        return "doc.text"
    }

    private func iconColor(_ entry: FileEntry) -> Color {
        let ext = entry.fileExtension
        if Self.videoExts.contains(ext) { return .orange }
        if Self.audioExts.contains(ext) { return .pink }
        return .gray
    }

    private func joinPath(_ name: String) -> String {
        if path.hasSuffix("/") { return path + name }
        return path + "/" + name
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

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            entries = try await api.listFiles(path: path)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func delete(_ file: FileEntry) async {
        do {
            try await api.removeFiles(dir: path, names: [file.name])
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func open(_ entry: FileEntry) async {
        var entry = entry
        let ext = entry.fileExtension
        entry.fullPath = joinPath(entry.name)
        if Self.imageExts.contains(ext) {
            viewerFile = entry
        } else if Self.videoExts.contains(ext) || Self.audioExts.contains(ext) {
            guard let url = await api.downloadURL(path: joinPath(entry.name)) else {
                errorText = "无法获取文件链接"
                return
            }
            playerFile = RemoteFile(url: url)
        } else {
            openFile = entry
        }
    }
    private func shareOrOpen(_ entry: FileEntry) async {
        guard let url = await api.downloadURL(path: joinPath(entry.name)) else {
            errorText = "无法获取文件链接"
            return
        }
        await MainActor.run {
            UIPasteboard.general.string = url.absoluteString
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

/// 可作为 .sheet(item:) 的远程文件引用。
struct RemoteFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// 未知类型文件:展示直链并提供浏览器打开。
struct UnknownFileSheet: View {
    let path: String
    let api: APIClient
    @Environment(\.dismiss) private var dismiss
    @State private var url: URL?
    @State private var loading = true

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text((path as NSString).lastPathComponent)
                .font(.headline)
                .lineLimit(3)
                .multilineTextAlignment(.center)
            if loading {
                ProgressView()
            } else if let url {
                Link(destination: url) {
                    Label("在浏览器中打开", systemImage: "safari")
                }
                .buttonStyle(.glassProminent)
            } else {
                Text("无法获取文件链接")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .task {
            url = await api.downloadURL(path: path)
            loading = false
        }
    }
}

/// 带鉴权头的远程图片缩略图。
struct RemoteImageView: View {
    let path: String
    let api: APIClient

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44)
        .clipShape(.rect(cornerRadius: 12))
        .task { await load() }
    }

    private func load() async {
        guard let url = URL(string: APIClient.normalizedBaseURL(api.baseURL) + "/d" + path) else { return }
        var request = URLRequest(url: url)
        if let token = api.token, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        request.cachePolicy = .returnCacheDataElseLoad
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse,
           (200..<300).contains(http.statusCode),
           let decoded = UIImage(data: data) {
            image = decoded
        }
    }
}
