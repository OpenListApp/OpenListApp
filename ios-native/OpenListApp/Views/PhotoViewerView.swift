import SwiftUI

/// 沉浸式图片查看器:双指/双击缩放 + 原生玻璃悬浮按钮。
struct PhotoViewerView: View {
    let entry: FileEntry
    let api: APIClient

    @Environment(\.dismiss) private var dismiss
    @State private var remoteURL: URL?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var errorText: String?

    private var entryPath: String {
        entry.fullPath ?? entry.name
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .gesture(
                                MagnifyGesture()
                                    .onChanged { value in
                                        scale = max(1, min(6, lastScale * value.magnification))
                                    }
                                    .onEnded { _ in lastScale = scale }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(duration: 0.35)) {
                                    scale = scale > 1 ? 1 : 2.5
                                    lastScale = scale
                                }
                            }
                            .animation(.spring(duration: 0.3), value: scale)
                    case .failure:
                        ContentUnavailableView("加载失败", systemImage: "photo.badge.exclamationmark")
                            .foregroundStyle(.white)
                    default:
                        ProgressView().controlSize(.large).tint(.white)
                    }
                }
                .ignoresSafeArea()
            } else {
                ProgressView().controlSize(.large).tint(.white)
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.glass)
                    Spacer()
                    Button {
                        Task { await delete() }
                    } label: {
                        Image(systemName: "trash")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.horizontal, 16)
                Spacer()
            }
        }
        .errorAlert($errorText)
        .task {
            remoteURL = await loadRemoteURL()
        }
    }

    private func loadRemoteURL() async -> URL? {
        // 优先 raw_url(带签名,公共可访问);失败回退 /d 直链。
        if let data = try? await api.fileGet(path: entryPath),
           let raw = data.raw_url,
           let url = URL(string: raw) {
            return url
        }
        return URL(string: APIClient.normalizedBaseURL(api.baseURL) + "/d" + entryPath)
    }

    private func delete() async {
        let dir = (entryPath as NSString).deletingLastPathComponent
        let name = (entryPath as NSString).lastPathComponent
        do {
            try await api.removeFiles(dir: dir.isEmpty ? "/" : dir, names: [name])
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
