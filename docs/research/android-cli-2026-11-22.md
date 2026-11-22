# Android CLI 能否替代 Android Studio，以及本仓怎么接（2026-11-22）

## 结论

- **工具已经有了，而且 Google 已把 SDK 管理迁到它上面。** Android CLI（命令名 `android`）2026-04 首发，当前版本 1.1.16919734（2026-11-13）。SDK 包 `cmdline-tools;latest` 23.0 自带 `bin/android` 启动器，同目录的 `sdkmanager` 已改成转调 `android sdk` 的 shim。官方的 [`sdkmanager`](https://developer.android.com/tools/sdkmanager) 和 [`avdmanager`](https://developer.android.com/tools/avdmanager) 页面都已标为 deprecated。
- **SDK 安装可以完全替代 Studio。** `android sdk install/list/update/remove` 会自动写 `licenses/`。包仍按经典布局装进 `~/Library/Android/sdk`，Gradle、Flutter、Studio 共用同一个根目录。
- **AVD 只能部分替代。**
  - [`android emulator create`](https://developer.android.com/tools/agents/android-cli/commands/emulator_create) 只接受一个预设 profile 名，没有分辨率、密度、API 或镜像参数。本机两台 2560×1440、240 dpi、API 30 `google_apis` 的车机 AVD 用它造不出来。
  - `list/start/stop/remove` 能管理已有 AVD。实测 `android emulator list --long` 能列出这两台。
  - [`start`](https://developer.android.com/tools/agents/android-cli/commands/emulator_start) 只有 `--cold` 和 `--headless`。agent 常用的 `-gpu`、`-feature -Vulkan`、`-camera-back`、`-ports`、`-no-audio` 仍要直接调 SDK 里的 `emulator`。
- **Studio 实际上已经不在 agent 的工作路径里。** 本机 Studio 最近一次运行是 2026-10-27 至 11-01。agent 直接调用 SDK 的 `emulator`、`avdmanager`、`sdkmanager`，从没用过 `android emulator`。车机 AVD 由 `mg4-helper/tools/emulator.py` 直接写 `config.ini`。
- **本仓的分工：CLI 本体交给 Nix，SDK 内容留在可写目录。** nixpkgs 已有 `android-cli`，按版本 URL 锁 hash，并带 `updateScript`。SDK 本身不用 `androidenv`，因为 AGP 和 Flutter 会往 SDK 根目录自动下载 NDK、CMake 和 platform，只读的 `/nix/store` 会让下载失败。`androidenv` 更适合 CI。
- **删 Studio cask 会丢数据。** `android-studio` cask 的 zap 会删除 `~/.android`（含 AVD 和 `adbkey`）与 `~/Library/Android/sdk`，本仓又设了 `cleanup = "zap"`。如果直接从 `modules/desktop/apps.nix` 删掉它，下一次 `just switch` 会把 SDK 和 AVD 一起删掉。

## 能力对照

| 任务 | Android Studio | Android CLI | 备注 |
|---|---|---|---|
| SDK 包 | SDK Manager | `android sdk install/update/remove/list` | 完全替代。包名用斜杠，如 `platforms/android-37.2`；分号写法仍兼容 |
| 许可 | 向导里点同意 | 自动写 `licenses/*` | Flutter 3.44.2 的 doctor 会误报 license unknown，见“已知问题” |
| 建 AVD | Device Manager，硬件参数可自定义 | `emulator create [<profile>]`，只有预设 | 预设固定 API 34–36.1 镜像，没有 API 30，也没有 2560×1440@240 |
| 启停 AVD | Device Manager | `emulator start [--cold] [--headless]`、`stop`、`list`、`remove` | 自定义启动参数仍需 `emulator` 二进制 |
| 构建、部署 | Gradle sync / Run | `build`、`run`、`install`、`describe` | Flutter 项目仍走 `fvm flutter` |
| UI 检查 | Layout Inspector | `layout`、`screen capture`、`input tap/text/swipe` | 只有只读树和截图，不能实时编辑 |
| Compose 预览 | 交互式 Preview | `preview render` → PNG | 不需要设备，也不需要 Studio |
| 性能 | Profiler UI | `profiler systemtrace/heapdump` | 查看 trace 仍需 Studio 或 Perfetto |
| 调试器 | 有 | 无；`run --debug` 只等待 attach | [INFERENCE] 官方没有列出这项差异，命令表里也没有调试器 |
| JDK | 自带 JBR | CLI 自带私有 JRE，只供自己用 | Gradle 和 Flutter 仍需要 `JAVA_HOME` 或 PATH 上的 `java` |
| IDE 语义分析 | 有 | `android studio …` 转发给 IDE | 需要正在运行的 Studio Quail 2+ |

`device remote`（云端真机串流）和 `signals`（Crashlytics / Android vitals）需要 Google 登录，其余命令不需要。

## 本机现状（awesome-macbook-air）

- SDK 位于 `~/Library/Android/sdk`，包括：build-tools 36.0.0/36.1.0/37.0.0；platforms android-35/36/37.0/37.1/37.2；NDK 28.2.13676358/30.0.16248370；CMake 3.22.1/4.1.2；cmdline-tools 23.0；emulator 37.2.12；system image `android-30/google_apis/arm64-v8a`。
- AVD：`MG4Mate_Android11_Preview` 和 `Supercar_Android11`，都是 2560×1440、240 dpi、横屏、无 Play Store，`image.sysdir.1` 写的是 SDK 内的绝对路径。
- **Android CLI 不是手动装的。** 2026-10-28 agent 运行 `sdkmanager` 下载 system image，shim 调用了 cmdline-tools 里的启动器。启动器随后把 `https://dl.google.com/android/cli/latest/darwin_arm64/android-cli` 下载到 `~/.android/bin/android-cli`，并新建了 `~/.android/cli/`、SDK 根目录下的 `.sdk/` 状态库和 `licenses/android-sdk-arm-dbt-license`。
  - 本机 `android-cli --version` 为 1.1.16717390，落后一个版本。运行时只提示 `Please run 'android update'`，不会自动替换二进制。
- **遥测一直开着。** `~/.android/cli/analytics/metrics/spool/` 积了 8 个 `.bproto`。`~/.android/analytics.settings` 里的 `hasOptedIn:false` 是 Studio 的开关，CLI 不认。
- Studio 日志 `~/Library/Logs/Google/AndroidStudio2026.2.1/idea.log` 的首行是 2026-10-27 11:11，末行是 11-01 11:12，之后再也没有运行过。
- JDK：`java` 不是全局可用（11-20 的 omp 会话里 `java -version` 报 `Unable to locate a Java Runtime`）。mise 装了 temurin-21 和 corretto-25，但只在项目内生效。没有 `flutter config --jdk-dir`，所以按查找顺序 Flutter 用的是 Studio 自带的 JBR（25.0.4）[INFERENCE]。

agent 命令中出现的次数（本机 omp 14 个项目目录共 224 个 JSONL、Codex 22 个 JSONL、DSH 30 个 session；含 `which` 一类探测）：

| 命令 | omp + Codex | DSH | 最后一次（omp + Codex） |
|---|---|---|---|
| SDK `emulator` 二进制 | 17 | 6 | 11-21 |
| `avdmanager` | 3 | 9 | 10-30 |
| `sdkmanager` | 5 | 12 | 11-21 |
| `android …`（新 CLI） | 5，都是 11-20 的 `sdk` 子命令和 `--help` | 0 | 11-20 |
| `./gradlew` | 241 | 456 | 11-21 |
| `adb` | 304 | 2904 | 11-21 |

DSH 在 10-28 的会话里每条命令都手写 `export ANDROID_HOME=$HOME/Library/Android/sdk` 和 `JAVA_HOME=$(mise where java@corretto-25.0.5.0.9)/Contents/Home`。omp 在 11-20 的会话里先探测 `JAVA_HOME= ANDROID_HOME=`，结果为空。这两个变量 agent 每次都要重新找。

## Nix 方案对比

| 方案 | 适合 | 问题 |
|---|---|---|
| **可写 SDK + nixpkgs `android-cli` + 环境变量** | 交互开发（本机） | 遥测默认开启，需要在 `~/.androidrc` 写 `--no-metrics`（已实测有效）。更新检查无法关闭，但每天最多 1 次、超时 2 s，只打印提示 |
| nixpkgs `androidenv.composeAndroidPackages` | CI、可复现构建 | SDK 只读，AGP/Flutter 的自动下载会失败；`buildToolsVersion`、`ndkVersion`、CMake 必须和 Gradle 声明完全一致（[nixpkgs 手册](https://nixos.org/manual/nixpkgs/unstable/#android)）。AVD 的 `image.sysdir.1` 会指向 store 路径，SDK 一升级就失效（[nixpkgs#428766](https://github.com/NixOS/nixpkgs/issues/428766)）。cmdline-tools 23 的 `bin/android` 启动器仍会下载未锁定的 CLI |
| [tadfisher/android-nixpkgs](https://github.com/tadfisher/android-nixpkgs) | CI、按包锁定 | 同样只读。它的 README 自己建议：需要装额外包时，要么改 Nix 表达式，要么改用标准 SDK |
| Homebrew `android-cli` cask | 不用 | 只装 3.6 MB 的启动器，运行时拉取未锁定的 `latest`；zap 会删 `~/.android` 和 `~/Library/Android` |
| 官方 `install.sh` | 不用 | 会往 shell rc 追加 `export PATH`，和 HM 管理的 zsh 冲突；同样拉取 `latest` |

nixpkgs `android-cli`（[package.nix](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/an/android-cli/package.nix)）：

- 用 `fetchurl` 下载 `https://dl.google.com/android/cli/${version}/<os_arch>/android-cli`，装成 `$out/bin/android`。Linux 上用 `autoPatchelfHook` 修补；Darwin 上原样安装。
- 支持 `x86_64-linux`、`aarch64-linux`、`aarch64-darwin`。许可是 unfree，Darwin 和 NixOS daily 都已开启 `allowUnfree`。
- 本仓当前锁定的两个 nixpkgs（nixos-unstable `d5cc683`、nixpkgs-unstable `5d2b81a`）都是 1.1.16717390。1.1.16919734 已在 2026-11-18 合入 nixpkgs master（[#589809](https://github.com/NixOS/nixpkgs/pull/589809)），会随每周的 `nix flake update` 进来。
- 打包时没有关闭遥测或更新检查。`android update` 无法覆盖只读的 store 二进制 [INFERENCE]。
- 运行时仍会把私有 JRE 和 `main.jar` 解压到 `~/.android/cli/bundles/<hash>/`。在 NixOS 上，这个 JRE 可能要靠 nix-ld 才能运行（daily 已开启 nix-ld）[UNVERIFIED]。

## 建议改动

最小改动只动 `modules/dev/languages.nix`（HM daily），本次没有修改：

```nix
home.packages = with pkgs; [
  # …
  android-tools
  android-cli
];

home.sessionVariables.ANDROID_HOME =
  if pkgs.stdenv.hostPlatform.isDarwin then "$HOME/Library/Android/sdk" else "$HOME/Android/Sdk";

# Android CLI 遥测默认开启；.androidrc 里的全局 flag 对每次调用生效。
home.file.".androidrc".text = "--no-metrics\n";
```

- `ANDROID_HOME` 只是把平台默认路径写明。CLI 和 Flutter 不设它也会找到默认 SDK；没有 `local.properties` 的项目直接跑 `./gradlew` 时需要它。以前由 Studio 在打开项目时写 `local.properties`。
- `.androidrc` 由 HM 管理后是只读 symlink。以后若要给 `signals`、`device remote` 设默认参数，也要写在这里。

**删掉 Studio（可选，需要你决定）：**

1. Mac 上先运行 `brew uninstall --cask android-studio`（不带 `--zap`），再从 `apps.nix` 的 `both` 中删除 `android-studio`，然后 `just switch`。顺序反过来会触发 zap，删掉 SDK 和 AVD。
2. 补 JDK。Flutter 找 Java 的顺序是 `flutter config --jdk-dir` → Studio 的 JBR → `JAVA_HOME` → PATH 上的 `java`（`packages/flutter_tools/lib/src/android/java.dart`）。删掉 Studio 后只剩后两项。可选做法：HM `programs.java`（会设 `JAVA_HOME`；JDK 21 能满足 AGP 9 的 JDK 17+ 要求），或用 `flutter config --jdk-dir` 指向 mise 的 JDK。
3. `both` 同时决定 NixOS 是否装 `pkgs.android-studio`。nixpkgs 的 Studio 是 FHS 包装，只有从 Studio 里启动的 SDK 二进制才能拿到完整的库。在终端启动 emulator，需要给 `programs.nix-ld.libraries` 补 GL、X11、音频等库（清单见 nixpkgs `androidenv/emulator.nix`）。awesome-pc 这次 SSH 连不上，没有验证，所以建议 NixOS 暂时保留 Studio。

**agent skill（可选）：** `android init` / `android skills add` 会往所有检测到的 agent 目录写 skill（`~/.agents/skills`、`~/.codex/skills` 等）。如果需要，可以按 mattpocock-skills 的做法，把 [`github:android/skills`](https://github.com/android/skills)（Apache-2.0）作为 `flake = false` 输入，在 `modules/agents/skills.nix` 里链接需要的 skill，例如 `devtools/android-cli`。不要运行 `android init`。

## 已知问题

- **Flutter 3.44.2 的 `flutter doctor` 会显示 “Android license status unknown”。** cmdline-tools 23 的 `sdkmanager --licenses` 只打印 `Warning: The --licenses option is no longer needed.` 后以 0 退出（本机实测），Flutter 匹配不到预期输出。这只影响 doctor 的显示，不影响构建，因为 AGP 读取的是 `licenses/` 里的文件。修复见 [flutter#191554](https://github.com/flutter/flutter/pull/191554)，3.47.3 和 3.50.0 已包含，3.44.2 没有（按 tag 拉取 `android_workflow.dart` 核对）。
- **未锁定的 CLI 仍可能被下载。** cmdline-tools 里的 `bin/android` 启动器和 `sdkmanager` shim 被调用时，仍会把未锁定的 CLI 下载到 `~/.android/bin/android-cli`。只要 nixpkgs 的 `android` 在 PATH 上，agent 直接调用 `android` 就会用锁定版本。`ANDROID_CLI_BIN` 只对 `sdkmanager` shim 生效。
- **已积压的遥测可能仍会上传。** 本机 spool 里已有的 8 个 `.bproto` 在开启 `--no-metrics` 后是否还会上传未验证。如有顾虑，可以手动删除 `~/.android/cli/analytics/metrics/spool/*`。
- **字节码结论有版本局限。** 文中来自字节码的结论（profile 清单、更新检查逻辑、agent 目录表）基于本机 1.1.16717390 的 bundle。

## 方法

- 本机只读检查：`ls`/`cat` 了 SDK、`~/.android`、AVD `config.ini`、Studio `idea.log`、`cmdline-tools/latest/bin/sdkmanager` 脚本；对启动器和 payload 跑了 `strings`；对 `main.jar` 解包后跑了 `strings`；`curl -I` 了 `dl.google.com/android/cli/{latest,1.1.16919734}/<os_arch>/{METADATA,android-cli}`。Linux payload 只取前 64 KiB 用 `file` 检查，结果是动态链接、解释器为 `/lib64/ld-linux-x86-64.so.2`。
- 遥测实测：设置 `HOME`、`ANDROID_USER_HOME` 和 `JAVA_TOOL_OPTIONS=-Duser.home=…` 指向 `/tmp`，并把 `ANDROID_CLI_ANALYTICS_URL`、`ANDROID_CLI_CRASH_URL` 指向 `127.0.0.1:9`，在隔离环境里运行 `~/.android/bin/android-cli`。结果：
  - 不加任何设置，每次调用都会在 spool 新增 1 个文件。
  - `--no-metrics` 参数，以及 `~/.androidrc` 里写 `--no-metrics`（单独成行或和 `--sdk=` 同行），都不会新增文件。
  - `DO_NOT_TRACK=1`、`CI=true` 无效。
- 真实环境里只运行了 `android-cli --no-metrics emulator list --long`，spool 前后都是 8 个文件。
- agent 用量：解析 `~/.omp/agent/sessions`、`~/.codex/sessions` 的 bash 工具调用，以及 `~/.dsh/sessions` 下 zstd 压缩的 `tool/call`，按命令正则计数。DSH 中的 `tauri android …` 是误匹配，已排除。
- Nix：`nix eval .#{darwin,nixos}Configurations.<host>.pkgs.android-cli.{version,meta.platforms}`，并阅读了 store 中的 `package.nix`；`brew info --cask {android-studio,android-cli} --json=v2` 用来读 zap 配置；`gh` 用来查 flutter PR/issue 状态和 nixpkgs compare。
- awesome-pc 的 SSH 被拒（`Connection closed`），所以 NixOS 部分的结论只来自源码。

## 来源

- Android CLI：[概览](https://developer.android.com/tools/agents/android-cli)、[下载](https://developer.android.com/tools/agents/android-cli/download)、[命令参考](https://developer.android.com/tools/agents/android-cli/commands)、[发布说明](https://developer.android.com/tools/agents/android-cli/release-notes)、[发布博客](https://developer.android.com/blog/posts/android-cli-build-android-apps-3x-faster-using-any-agent)
- 弃用说明：[sdkmanager](https://developer.android.com/tools/sdkmanager)、[avdmanager](https://developer.android.com/tools/avdmanager)
- AGP 自动下载 SDK 组件：[Update the IDE and SDK tools](https://developer.android.com/studio/intro/update#download-with-gradle)、[Install NDK](https://developer.android.com/studio/projects/install-ndk)
- Flutter：[Android setup](https://docs.flutter.dev/platform-integration/android/setup)、[flutter#191487](https://github.com/flutter/flutter/issues/191487)、[flutter#191554](https://github.com/flutter/flutter/pull/191554)、[flutter#192133](https://github.com/flutter/flutter/pull/192133)、[flutter#189936](https://github.com/flutter/flutter/issues/189936)（`sdkmanager` 迁移到 `android`，仍未关闭）
- Nix：[nixpkgs Android 手册](https://nixos.org/manual/nixpkgs/unstable/#android)、[androidenv 源码](https://github.com/NixOS/nixpkgs/tree/master/pkgs/development/mobile/androidenv)、[nixpkgs#572177](https://github.com/NixOS/nixpkgs/pull/572177)（androidenv 绕开 cmdline-tools 23 的 `sdkmanager` shim）、[tadfisher/android-nixpkgs](https://github.com/tadfisher/android-nixpkgs)、[NixOS wiki Android](https://wiki.nixos.org/wiki/Android)
- Agent skills：[android/skills](https://github.com/android/skills)、[android/android-cli-plugin](https://github.com/android/android-cli-plugin)

## 处理结果（2026-11-22）

- `modules/dev/languages.nix`：
  - 新增 nixpkgs `android-cli`。
  - `ANDROID_HOME` 设为各平台的默认 SDK 路径。
  - HM 写入 `~/.androidrc`，内容为 `--no-metrics`。
- `modules/desktop/apps.nix`：删除 `android-studio`，Mac 和 NixOS 都不再安装。
  - Mac 下次 switch 时，`cleanup = "zap"` 会按 cask 的 zap 配置把 `~/.android` 和 `~/Library/Android/sdk` 移进废纸篓。用户确认这些数据都能重建：SDK 用 `android sdk install` 重装，AVD 用项目仓库里的脚本重新生成。
  - zap 也会移走 `~/.android/adbkey`，新生成的 key 需要在车机和手机上重新授权 USB 调试。
- 未处理 JDK：Flutter 不再能用 Studio 自带的 JBR，改为依赖 `JAVA_HOME` 或 PATH 上的 `java`（各项目由 mise 固定版本）。
- 未在 awesome-pc 上验证终端直接启动 emulator：没有 Studio 的 FHS 环境后，可能需要给 `programs.nix-ld.libraries` 补 GL、X11、音频等库。
- 同日后续：删除 nixpkgs `android-cli`。用到它的项目在自己的 mise 配置里锁版本，例如 supercar 的 `.mise.toml` 写 `android-cli = "1.1.16717390"`；同一份配置还服务 Windows 和 CI，Nix 管不到。`ANDROID_HOME` 和 `~/.androidrc` 保留在 HM。
  - mise 的 `http:android-cli` 下载 `dl.google.com/android/cli/<version>/<os_arch>/android`，即 3.6 MB 的启动器，版本号只锁启动器。启动器首次运行时从 `latest` 下载 payload 到 `~/.android/bin/android-cli`：本机 mise 锁 1.1.16717390，payload 实测是 1.1.16919734。上文“只要 nixpkgs 的 `android` 在 PATH 上，就会用锁定版本”不再适用。
  - `~/.androidrc` 对 mise 安装的 CLI 同样生效：payload 已运行过，`~/.android/cli/analytics/metrics/spool/` 不存在。
