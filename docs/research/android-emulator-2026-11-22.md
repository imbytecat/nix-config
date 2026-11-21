# Agent 时代的 Android 模拟器选型（2026-11-22）

## 结论

- **继续用 Google 官方模拟器（AVD），不换 Genymotion。** Genymotion Desktop 解决不了现在卡住的问题，还缺 agent 最需要的能力：
  - [官方 FAQ](https://support.genymotion.com/hc/en-us/articles/360000290798-Can-Genymotion-Desktop-run-in-a-server-Is-there-a-headless-mode) 明确写着 “there is no headless mode”。[安装文档](https://docs.genymotion.com/quickstart/desktop_install/)也写明 VM、VPS、Docker 和服务器都不支持，Apple Silicon 上必须开 Rosetta。
  - 免费版按[条款](https://www.genymotion.com/legal-terms-and-conditions/)只限个人、非商业用途。商用要 Indie $239.99/年或 Business $479.99/年（[定价](https://www.genymotion.com/pricing/)）。相机/媒体注入、网络档位、GPS 路线、运动传感器都是付费功能。
  - 车机相关：桌面版没有 Automotive 镜像；多屏是实验功能，只能在 GUI 里配；相机只有前、后两路。
- **其他选项都不比 AVD 更合适。**
  - [Cuttlefish](https://source.android.com/docs/devices/cuttlefish) 只能在 Linux + KVM 上运行，macOS 只做编译检查；镜像是 AOSP 构建，官方定位是平台开发。
  - Redroid 和 Waydroid 没有条件模拟，只有单屏，也没有相机。
  - BlueStacks、MuMu 是游戏向产品。
- **卡点是通用模拟器的保真边界，换品牌解决不了。** 四路相机、厂商车辆服务（零束 Binder、CAN）、仪表协议、音质，任何通用模拟器都复刻不了。可行做法是 AVD 负责界面、流程和条件，厂商能力由“底座”给模拟器一个模拟实现，最终验收在实车上做。
- **具体卡点逐个看：**

| 卡点 | 实测或文档 | 做法 |
|---|---|---|
| 四路相机 | 运行中的 API 30 AVD 报告 `Number of camera devices: 2`：后摄是单路；前摄是逻辑相机，物理子相机 ID 为 24/25/26（来自 `/vendor/etc/config/emu_camera_front.json`）。[相机文档](https://developer.android.com/studio/run/emulator-use-camera)里 Android 11+ 的 “Logical camera support / Concurrent cameras” 指的是 Camera2 能力，并没有说能接四路宿主画面 | 宿主只能给前、后两路喂画面，来源可以是 `videofile:`、`imagefile:` 或 `webcamN`。另外两路在底座的相机抽象里用模拟源；真四路在实车验收 |
| 音乐有沙沙声 | 本机 emulator 是 37.2.12。[37.3.10](https://developer.android.com/studio/releases/emulator)（2026-11-19）修复了 macOS CoreAudio 竞态（#357859014）、默认音频设备切换（#357855425）和 App Nap 造成的卡顿（#562546399） | 先升级到 37.3.10；带窗口运行时用 `-gpu host`，不用 `swiftshader`；`hw.audioInput=no`；音质最终以真机为准 |
| 仪表副屏 | 镜像里有 `com.android.emulator.multidisplay`（实测）。`hardware-properties.ini` 有 `hw.display1..3.*` | 写 `hw.display1.width/height/density/flag`，或启动参数 `-multidisplay 1,<w>,<h>,<dpi>,<flag>`；运行时用 `adb emu multidisplay add 1 <w> <h> <dpi> 0` |
| agent 跑 headless，人想看画面 | [`android device hub`](https://developer.android.com/tools/agents/android-cli/commands/device_hub)：串流画面**和声音**，带电池、蜂窝、麦克风、指纹、多屏等扩展控制；关窗口不会停模拟器 | `android device hub --device=emulator-5564`。替代方案是 scrcpy（nixpkgs 5.0.1），用 `--display-id=1` 看副屏 |
| 模拟器写进仓库 | `android emulator create` 只有预设 profile；`avdmanager` 已弃用；没有官方的自定义硬件声明格式 | 现有 `tools/emulator.{json,py}`（`config.ini` 模板加启动脚本）就是正确做法，key 以 `emulator/lib/hardware-properties.ini` 为准 |

## 条件测试速查

以下命令都可以在 headless 模式下运行，agent 能直接调用。`adb emu …` 的子命令已在本机 37.2.12 用 `emu help` 核对；`adb shell cmd …` 已在 API 30 镜像上核对存在。

| 条件 | 命令 |
|---|---|
| GPS 定点 / NMEA | `adb emu geo fix <经度> <纬度>`、`adb emu geo nmea '$GPRMC,…'` |
| GPS 轨迹 | 控制台不支持导入 GPX/KML，那是 GUI 功能。headless 下用脚本循环调用 `geo fix`，或通过 gRPC `setGps` |
| 网速 / 延迟 | `adb emu network speed edge`、`adb emu network delay umts`；也可以用启动参数 `-netspeed`、`-netdelay` |
| 飞行模式 | `adb shell cmd connectivity airplane-mode enable` |
| 电量 / 充电 | `adb emu power capacity 15`、`adb emu power ac off`、`adb emu power status discharging` |
| 来电 / 短信 | `adb emu gsm call <号码>`、`adb emu sms send <号码> <内容>` |
| 传感器 | `adb emu sensor set acceleration <x>:<y>:<z>` |
| 定位开关 / 深色模式 | `adb shell cmd location set-location-enabled false`、`adb shell cmd uimode night yes` |
| 快照（快速复位） | `adb emu avd snapshot save <名称>` / `load <名称>` |
| 宏录制回放 | `adb emu automation record <文件>` / `play <文件>` |
| 录屏 | `adb emu screenrecord start <文件>.webm` |
| 同一 AVD 开多个实例 | `-read-only` 加不同的 `-ports`（这种实例不能保存快照） |

所有能力都受这个限制：蓝牙模拟（netsim）要 API 31+，现有 AVD 是 API 30。

## 选项对比

| 方案 | Mac Apple Silicon | Linux x86_64 | headless | 费用 | 车机相关 |
|---|---|---|---|---|---|
| **AVD** | arm64 镜像原生加速 | KVM + x86_64 镜像；x86_64 镜像里运行 ARM 库靠逐进程翻译，许可只限开发调试 | ✓（`-no-window`、`android emulator start --headless`） | 免费 | 自定义分辨率和密度；最多 3 块副屏；2 路宿主相机；条件可脚本化 |
| Genymotion Desktop | arm64，Android 11/12.1/13–16，要 Rosetta | QEMU + KVM，只支持工作站 | ✗ | 商用 $239.99–479.99/年 | 无 Automotive 镜像；多屏实验且只能 GUI 配；相机前/后两路（付费） |
| Genymotion SaaS/PaaS | 浏览器 / `gmsaas` | 自己的云账号 | ✓ | $0.06/分钟起，或 $0.60/小时加云费用 | Automotive 14 beta 镜像不支持相机 |
| Cuttlefish | ✗ | KVM；deb 包、Docker、`podcvd` | ✓（WebRTC） | 免费 | `--display` 多屏，`aosp_cf_x86_64_auto_md` 仪表 target；AOSP 镜像无 Google APIs |
| Redroid / Waydroid | ✗ | Docker `--privileged` / Wayland 会话 | Redroid ✓ | 免费 | 单屏、无条件模拟、无相机 |

## 云端真机

- [Android Device Streaming](https://developer.android.com/studio/run/android-device-streaming)：`android device remote …`，每月 30 分钟免费，之后 $0.15/分钟（[配额](https://firebase.google.com/docs/test-lab/usage-quotas-pricing)）。机型是手机，没有车机。
- Firebase Test Lab 已宣布弃用，2027-09-30 关闭，迁移到 Developer Device Platform（[FAQ](https://firebase.google.com/docs/test-lab/migrate-faq)）。

## 建议动作

1. 停掉正在运行的模拟器（目前 `emulator-5564` 和 `emulator-5582` 在跑），然后 `android sdk update emulator` 升级到 37.3.10。37.3.10 修复了加载 37.2 快照时的崩溃，但升级后第一次最好冷启动。
2. supercar 的 `tools/emulator.py` 在 headless 模式下固定使用 `-no-window -no-audio -gpu swiftshader`。11-20 已有 agent 用 `-no-window -gpu host` 成功启动过，可以改成 `host`；只在不需要声音时加 `-no-audio`。
3. 实车测出仪表屏尺寸后，在 `tools/emulator.json` 里加上 `hw.display1.*`。
4. 相机：前、后两路用 `videofile:` 喂录好的行车画面；另外两路在底座里用模拟源；四路并发、编码余量这类结论只在实车上下。
5. 要看画面时用 `android device hub`，不用再让 agent 改成带窗口重启。
6. 可选：如果要做 headless 设备农场，放在 OVH 裸机上，用 Google 的 [android-emulator-container-scripts](https://github.com/google/android-emulator-container-scripts)。Proxmox VM 需要嵌套虚拟化，官方文档不支持在虚拟机里运行加速模拟器。

nix-config 不需要改：`device hub` 由 Android CLI 首次运行时自动下载扩展包；scrcpy 只是可选项。

## 只用 Android CLI 够不够，要不要用 Nix 装 avdmanager

**不用装 avdmanager。**

- nixpkgs 没有单独的 `avdmanager`：`pkgs.avdmanager` 不存在（实测）。它只能随 `androidenv` 的只读 SDK 一起装。
- 脚本用 `-Dcom.android.sdkmanager.toolsdir=$APP_HOME` 按自身位置确定 SDK 根，所以 Nix 装的副本会去 store 里的 SDK 找系统镜像 [INFERENCE，未试 `--sdk_root`]。
- 可写 SDK 的 cmdline-tools 23.0 里本来就有 `avdmanager`。它已被官方弃用，运行还需要 JDK。
- 它也解决不了车机硬件：`create avd` 只能选 `-d <设备定义>`，没有分辨率、密度或副屏参数，最后仍要改 `config.ini`。`supercar/tools/emulator.py` 已经直接写 `config.ini`，从没调用过 `avdmanager`。

Android CLI 的真正缺口是 `emulator start` 只有 `--cold`/`--headless` 两个参数。不变的设置可以写进 AVD 的 `config.ini`（key 以 `hardware-properties.ini` 为准），之后 `android emulator start --headless <AVD>` 就够用：

| 原启动参数 | `config.ini` |
|---|---|
| `-gpu host` | `hw.gpu.mode=host`（可选值 auto/host/software） |
| `-no-audio` | `hw.audioOutput=no`、`hw.audioInput=no` |
| `-multidisplay 1,…` | `hw.display1.width/height/density/flag`；`hw.multi_display_window=yes` 时每块屏开一个窗口 |
| `-no-snapshot-load` | `fastboot.forceColdBoot=yes`，或 `android emulator start --cold` |

实测（2026-11-22，emulator 37.2.12，Android CLI 1.1.16717390）：

- 用 `MG4Mate_Android11_Preview` 的 `config.ini` 新建一个临时 AVD，只改小内存和核数，并追加 `hw.display1.width=1280`、`hw.display1.height=480`、`hw.display1.density=160`、`hw.display1.flag=0`。
- `android emulator start --headless` 23 s 完成启动。
- `dumpsys display` 显示 display 0 为 2560×1440、240 dpi，display 1 为 “Emulator 2D Display” 1280×480。
- `am start --display 1` 后，Settings 在 display 1 上处于 resumed 状态；`screencap -d 1` 截到 1280×480 的画面。
- 只设 `ANDROID_USER_HOME` 时，CLI 能列出该 AVD，但 emulator 37.2.12 不会去 `$ANDROID_USER_HOME/avd` 查找（日志说明它只搜 `$ANDROID_AVD_HOME`、`$ANDROID_SDK_HOME/avd`、`~/.android/avd`）。AVD 不放在默认位置时，要同时设 `ANDROID_AVD_HOME`。

还需要直接调 SDK 里的 `emulator` 的只剩按次变化的参数：`-read-only`、`-ports`、`-feature`、`-netspeed/-netdelay`（运行中也可以用 `adb emu network …`），以及 `-camera-back videofile:…`。`hw.camera.back` 的 enum 只列了 `emulated, none, webcam0, ...`，把视频源写进 `config.ini` 是否生效没有实测。

分工：

| 事情 | 工具 |
|---|---|
| SDK、emulator、系统镜像 | `android sdk install/update` |
| 创建车机 AVD | 仓库脚本生成 `config.ini`（现有 `tools/emulator.py`） |
| 启停、列出 AVD | `android emulator start --headless` / `stop` / `list` |
| 看画面和声音 | `android device hub` |
| 交互、截图、布局 | `android input` / `screen` / `layout` |
| 运行时条件 | `adb emu …`、`adb shell cmd …` |
| 按次变化的启动参数 | SDK 自带的 `emulator` |

工具全部切到 Android CLI 之后，仍然解决不了四路相机、厂商车辆服务、仪表协议和音质。这些是模拟器的保真边界，不是工具问题。

## 方法

- 本机只读检查：
  - `adb devices -l`；对正在运行的 API 30 AVD 执行了 `adb emu help <cmd>`、`adb shell dumpsys media.camera`（相机数量、物理子相机 ID）、`ls /vendor/etc/config/emu_camera_*.json`、`pm list packages | grep emulator`，以及 `cmd connectivity|uimode|location help`。
  - `emulator -help`、`emulator -help-camera-back`；在 `emulator/lib/hardware-properties.ini` 里 grep 了 `hw.camera.*`、`hw.display1..3.*`。
  - `nix eval` 查了 `scrcpy` / `genymotion` 的版本和平台；`brew info --cask genymotion`。
- 痛点来源：omp、Codex 会话里提到“模拟器”的用户提问及之后的 agent 结论，包括 10-28 复刻车机和副屏、11-21 多路摄像头、11-21 音频沙沙声、11-21 想看 headless 画面；另外读了 `supercar/tools/emulator.{json,py}` 和 `mg4-helper/README.md`。
- 文档核对：emulator 37.3.10 发布说明、`device hub` 命令页、相机页，以及 Genymotion 的 headless FAQ、安装要求、个人使用条款、定价页，都是直接抓取原文核对的。Cuttlefish、Redroid、Waydroid、Device Streaming 和 Test Lab 的事实来自子 agent 引用的一手页面，正文已附链接。
- 未实测：没有在升级 emulator 后复测音频；没有验证把 `videofile:` 写进 `config.ini` 是否生效；Genymotion 和 Cuttlefish 都没有安装试用。
