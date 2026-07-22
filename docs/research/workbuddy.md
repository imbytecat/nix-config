# WorkBuddy 的 Linux 与 nixpkgs 支持情况

调查日期：2026-07-22

## 结论

这里的 WorkBuddy 指腾讯推出的职场 AI 智能体桌面工作台，不是同名的外勤管理 SaaS `workbuddy.com` 或其他 GitHub 项目。

- 腾讯目前没有提供 WorkBuddy Linux 桌面客户端。官方下载只列出 macOS ARM64、macOS x64 和 Windows x64，官方文档也只有 Windows 与 Mac 安装指南。
- 官方提供 [WorkBuddy 网页版](https://www.workbuddy.cn/app)，可以从 Linux 浏览器访问，但不能据此假定它具备桌面客户端的全部本地文件与系统集成能力。
- nixpkgs 当前没有 `workbuddy` 包。本仓库锁定的 nixpkgs 提交 `421eebfd0ec7bccd4abe826ce62d7e6e83129493` 和调查时的 nixpkgs master 提交 `53d5cb0cd5e4402f4e791940cc3ec94ffbf50ddd`，执行 `nix search ... workbuddy --json` 都返回 `{}`；源码中也没有匹配项。
- 因此目前不能直接在桌面模块里写 `pkgs.workbuddy`。

## 社区 Linux 方案

[hzleihuan/workbuddy-linux](https://github.com/hzleihuan/workbuddy-linux) 是非官方转换工具：从用户自行取得的官方 Intel Mac DMG 提取 Electron 应用，再重建 Linux 原生模块，可在本地生成 DEB、RPM、Arch 包或 AppImage。

该方案不是腾讯发布的 Linux 客户端，也不在 nixpkgs/AUR。仓库没有 GitHub Releases 或 Tags，应用内自动更新不可用；README 还说明 AI 代码沙盒可能降级为真实终端执行或拒绝执行。因此即使后续自行打包，也应把它视为需要人工审计和维护的闭源应用移植方案。

## 一手来源

- [腾讯 WorkBuddy 官网](https://www.workbuddy.ai/)
- [腾讯 WorkBuddy 简介与官方文档目录](https://www.workbuddy.ai/docs/zh/workbuddy/Overview)
- [Windows 安装指南](https://www.workbuddy.ai/docs/zh/workbuddy/From-Beginner-to-Expert-Guide/Installation-Win-Guide)
- [Mac 安装指南](https://www.workbuddy.ai/docs/zh/workbuddy/From-Beginner-to-Expert-Guide/Installation-Mac-Guide)
- [NixOS 官方包搜索](https://search.nixos.org/packages?channel=unstable&query=workbuddy)
- [调查时的 nixpkgs master 提交](https://github.com/NixOS/nixpkgs/commit/53d5cb0cd5e4402f4e791940cc3ec94ffbf50ddd)
- [本仓库锁定的 nixpkgs 提交](https://github.com/NixOS/nixpkgs/commit/421eebfd0ec7bccd4abe826ce62d7e6e83129493)
- [非官方 Linux 转换工具](https://github.com/hzleihuan/workbuddy-linux)

