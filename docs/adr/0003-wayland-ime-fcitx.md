# Wayland 下 fcitx5 输入法：为何不全局设 *_IM_MODULE，及各程序如何点亮

## 背景

awesome-pc 是 Plasma 6 Wayland-only。fcitx5 开 `waylandFrontend = true`，让原生
Wayland 程序走 text-input-v3 直连 fcitx5。此时**故意不全局设** `QT/GTK_IM_MODULE`：
全局设会把原生 Wayland 程序拖去走 XIM，反而破坏 waylandFrontend（nixpkgs#278765）。

代价：XWayland 下的旧程序（尤其 Qt5）看不到 fcitx5 输入上下文，需逐个点亮。

## 各处怎么接（跨文件）

- **原生 Wayland 程序**：`waylandFrontend = true`（`modules/desktop/nixos.nix`）走 text-input-v3。
- **XWayland / 不支持 text-input 的旧程序**：另需把 fcitx5 注册为 KWin 虚拟键盘
  （`kwinrc` `[Wayland] InputMethod`，`home/desktop/plasma.nix`），走 input-method-v2。
  与 waylandFrontend 互补、二者都要。
- **微信 4.x**（XWayland Qt5，二进制内置 fcitx-qt5）：只有 `QT_IM_MODULE=fcitx` 才会加载
  输入上下文，故 `symlinkJoin` wrap 单独注入 `QT/GTK_IM_MODULE` + `XMODIFIERS`。微信外层是
  bwrap 且未 `--clearenv`，环境变量透传进沙箱；内置 fcitx-qt5 经 `$XDG_RUNTIME_DIR` 的 DBus
  连 fcitx5。QQ 是 Electron，靠 `--enable-wayland-ime` 走 text-input-v3，不受影响。
- **WPS**（同微信，XWayland Qt5，已内置 `libsForQt5.fcitx5-qt` 插件）：四个入口
  `wps/et/wpp/wpspdf` 各 wrap 注入同样三个变量。
- **rime-ice**：nixpkgs 把上游 `default.yaml` 改名为 `rime_ice_suggestion.yaml`（避免与其他
  方案包抢占全局配置），需用户侧 `default.custom.yaml` 显式 `__include` 才有候选，否则
  `schema_list` 为空、无候选框（nixpkgs#449487）。该文件由 home-manager 管
  （`home/desktop/fcitx5.nix` 的 `xdg.dataFile`）。走用户路径而非 NixOS `ignoreUserConfig`：后者设
  `SKIP_FCITX_USER_PATH` 会跳过整个用户目录，连 rime 编译方案所需的可写目录
  （`~/.local/share/fcitx5`：build/、userdb）一起跳，直接弄坏输入法。

## 关联

- `modules/desktop/nixos.nix` —— `waylandFrontend`、微信 / WPS wrap、rime addon
- `home/desktop/plasma.nix` —— KWin `InputMethod`
- `home/desktop/fcitx5.nix` —— fcitx5 profile、rime `default.custom.yaml`
