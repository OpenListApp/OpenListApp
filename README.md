# OpenList App

OpenList / AList 的原生 iOS 客户端,基于 SwiftUI 与 iOS 26 苹果原生液态玻璃(Liquid Glass)构建,无任何 WebView。

- **iOS**:本仓库 `ios-native/` 目录(Xcode 工程)
- **Web**:由服务器自带网页端提供,浏览器访问服务器地址即可使用

Android、Windows、Linux、macOS 端代码已移除。

## 功能

- 登录 / 访客模式(跳过登录)
- 存储管理:添加(动态驱动表单)、启用 / 停用、删除
- 文件浏览:目录导航、图片缩略图与查看、视频播放、删除 / 下载
- 任务:未完成 / 已完成与进度
- 我的:服务器设置、退出登录

## 本地构建

需要 Xcode 26 或更高版本(iOS 26 SDK):

```bash
cd ios-native
open OpenListApp.xcodeproj
```

选择 OpenListApp scheme,直接运行。

## CI 自动构建

推送 `ios-native/**` 的改动,或在 Actions 页手动触发后,工作流会自动构建**未签名 IPA**,在构建页底部的 Artifacts 下载 `OpenListApp-iOS-unsigned-ipa`:

- TrollStore 可直接安装
- 或用自有证书重签后安装

## 许可证

GPL-3.0
