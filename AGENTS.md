# AGENTS.md

## Overview

Nix flake — 2 台 Darwin（Mac mini + MacBook Air，均 aarch64-darwin）+ 1 台 NixOS PC（x86_64-linux）+ 1 台单臂透明代理网关 mihomo-gateway（x86_64-linux）。日用机单用户 `imbytecat`，网关单用户 `root`。Uses **Lix**.

## Architecture

```
flake.nix
├── darwinConfigurations.awesome-mac-mini    (aarch64-darwin)
├── darwinConfigurations.awesome-macbook-air (aarch64-darwin)
├── nixosConfigurations.awesome-pc           (x86_64-linux, 日用)
└── nixosConfigurations.mihomo-gateway       (x86_64-linux, 网关，root-only，模块隔离)
```

flake attr / 目录名 / `networking.hostName` 三者保持一致，加新机器请遵循这条规则 —— justfile 的 `_guard` 直接拿 `hostname -s` 跟 host 参数对比，不需要任何 map 或额外 eval。

- `lib/default.nix` — `mkDarwin`/`mkNixos`/`mkServer` builders, `sshKeys` (via `specialArgs`), `homeManagerConfig`
- `modules/shared/` — cross-platform: Lix, overlays, fonts, fish, openssh, 1password
- `modules/darwin/` — `default.nix` 是两台 Mac 共享的全部配置（user / sudo / Touch ID / system.defaults / 全套 homebrew casks + brews + masApps）。两台机器跑相同的桌面应用，单机差异（如 `awesome-macbook-air` 的 `thaw`、`awesome-mac-mini` 的常开机电源策略）放 `hosts/<host>/default.nix`
- `modules/nixos/` — system packages, locale, docker, user（**仅日用**，网关不导入）
- `modules/gateway/` — mihomo + nftables TPROXY + 单臂 networking + resolved（**仅网关**）
- `home/` — home-manager (shared, `useGlobalPkgs`), catppuccin（**仅日用**，网关不导入）
- `hosts/*/` — per-host overrides；`hosts/mihomo-gateway/{default,disko}.nix` 提供网关 host-level 配置（boot/disko/openssh/timezone/stateVersion/SJTU 镜像）
- `overlays/` + `pkgs/` — custom packages (`comment-checker`) + `numtide/llm-agents.nix` overlay（暴露 `pkgs.llm-agents.{opencode,skills,...}`）
- `.agents/skills/` — Agent skills（如 `mihomo/SKILL.md`：Mihomo CLI 速查 + TPROXY 深度排查手册）

Flow:
- 日用机：`hosts/*` → `modules/{shared,darwin|nixos}` → `home/*`
- 网关：`hosts/mihomo-gateway` → `modules/gateway` + `modules/shared/nix.nix`（**只**复用 nix.nix，不走 default.nix / fonts / fish / 1password）

## Commands

```bash
# 本机重建（hostname 不匹配会被 _guard 拒绝）
just switch awesome-mac-mini    # macOS host (darwin-rebuild switch)
just switch awesome-macbook-air
just switch awesome-pc          # NixOS host (nixos-rebuild switch)
just switch mihomo-gateway      # 在网关本机跑（不是远程 push）
just build <host>               # 仅构建不激活，配合 just diff <host> 看包差异
just boot <host>                # 仅注册下次启动 generation（NixOS only）

# 远程 NixOS 主机（任意 nixosConfigurations.<host> 都可，不限网关）
just install <host> <remote>    # 首装：nixos-anywhere（kexec → disko 全盘 → install → reboot）
just deploy <host> <remote>     # 更新：nixos-rebuild switch --target-host
just deploy-boot <host> <remote> # 更新但仅注册下次启动 generation（kernel/initrd，需 reboot）

# 检查 / 诊断
just eval                       # eval 本平台所有 host
just check                      # nix flake check
just dry <host>                 # dry-run，列出 build/fetch 列表，定位 cache miss
just diff <host>                # 自动 build + nvd diff /run/current-system result/

# flake / 维护
just update                     # nix flake update
just up nixpkgs                 # update single input
just gc                         # nix-collect-garbage --delete-older-than 7d
just rollback                   # NixOS only — rollback to previous generation
just history                    # list system profile generations
just show                       # nix flake show
just fmt                        # nix fmt（走 flake.formatter）
just repl                       # nix repl -f flake:nixpkgs
just lsp <host>                 # nixd option completion for VSCode（自动探测 darwin/nixos + 有无 HM）

# 一次性环境（无需 HM 已装齐）
nix develop                     # just / jq / nixfmt / nixd / statix / nvd
```

Note: `just eval`、`just switch`、`just build`、`just deploy`、`just boot`、`just dry` 都有 `[macos]`/`[linux]` 变体 —— justfile 按当前执行机平台自动选。`install` / `check` / `diff` / `lsp` 等跨平台单一实现。

**远程 NixOS 部署，两条路径并存**：
- Linux 执行机 → 同架构 NixOS：本机构建后 SCP 推送，最快
- macOS 执行机 → NixOS（必跨架构）：macOS 变体加 `--build-host root@<target>` 让目标机自己 build，避开 Mac 上跑 Linux 构建
- `install` 一律 `--build-on remote`，所以执行机平台不影响首装

**`_guard` 怎么工作**：flake attr / 目录 / `networking.hostName` 三者完全一致，所以 `_guard` 只做一件事 —— `[[ "$(hostname -s)" == "{{host}}" ]]`，不匹配就 refuse。零 nix eval、零延迟。`_valid host` 用 `{{quote()}}` 防止 shell 注入，所有 host-接收的 recipe 都通过它把 host 参数过一遍。

## Gotchas

- **Shared settings in `modules/shared/`** — don't re-declare fish/openssh/1password/fonts in platform modules.
- **`sshKeys` centralized** in `lib/default.nix` via `specialArgs`. Don't hardcode.
- **Neovim = lazyvim-nix** — `programs.lazyvim` in `home/dev/neovim.nix`. `catppuccin.nvim.enable = false` (LazyVim manages colorscheme). The `lazyvim.homeManagerModules.default` is loaded as a sharedModule in `lib/default.nix`.
- **catppuccin modules** — `catppuccin.homeModules.catppuccin` (home), `catppuccin.nixosModules.catppuccin` (NixOS). Not the old `homeManagerModules`.
- **Homebrew `cleanup = "zap"`** — undeclared casks/brews get removed. `greedyCasks = true` upgrades even auto-updating casks. **Casks 两层**：(1) 两台 Mac 共享的全部 cask + brews + masApps + taps 在 `modules/darwin/default.nix`；(2) 单机差异 cask 写 `hosts/<host>/default.nix`（如 `thaw` 在 `awesome-macbook-air`）。Tap casks 需要完整路径（`"goooler/repo/fl-clash"`）。**Chromium 走 `ungoogled-chromium`**（普通 `chromium` cask 公证有问题，会被 Gatekeeper 拦）。**`brew bundle cleanup` 不动 mas apps**（见下条）所以 `masApps` 只留 MAS 独占的项。
- **Homebrew 本体由 `nix-homebrew` 声明式接管** — `modules/darwin/default.nix` 顶部 `imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ]`，`enable + autoMigrate + mutableTaps=false` 把 brew + 4 个 tap（`homebrew-core/cask/goooler/imbytecat`）从 flake input 符号链接进 `/opt/homebrew/Library`。**裸机无需手工 install.sh**。**brew 本体不再顶层 pin**：`flake.nix` 删掉了 `brew-src` override，由 `nix-homebrew` 自带的 `brew-src` 提供（当前 6.0.1，随 `just update` 升 nix-homebrew 一起走）。nix-darwin **已合并 PR #1789**，activation 改用 brew 6.x 的 `--force-cleanup`（`cleanup="zap"` → `--zap --force-cleanup`）并支持 Brewfile `trusted: true`。brew 6.0 默认开 `HOMEBREW_REQUIRE_TAP_TRUST`，**非官方 tap（`goooler/repo`、`imbytecat/tap`）必须写成 `{ name = "..."; trusted = true; }`**，官方 tap 仍是纯字符串（永远受信，无需标）；brews/casks 的 `trusted` 默认就是 `true`，自动带上。**`homebrew.taps` 必须列全所有 nix-homebrew 管的 tap**（含 `homebrew/homebrew-core/cask`），否则 `cleanup="zap"` 会尝试 untap 被符号链接的 tap 报错。**已有 brew 用户首次接管会爆**：`/opt/homebrew/README.md` 含 🍺 emoji 会让 `nuke-homebrew-repository:33` 的 `grep -E '^# Homebrew'` 失败（`sudo bash -c 'echo "# Homebrew" > /opt/homebrew/README.md'`）；接着 `Library/Taps` 与 `bin/brew` 也需 `sudo rm -rf` / `sudo rm -f`，nix-homebrew 才能放符号链接。`autoUpdate = false`（onActivation）是必须的：关掉运行时 `git pull` 漂移。
- **`brew bundle cleanup` 不动 mas apps** — [Homebrew/homebrew-bundle#1077](https://github.com/Homebrew/homebrew-bundle/issues/1077)，已知限制：`mas uninstall` 要 root 且 Apple 在缩 mas 用的私有 API。从 `masApps` 删一项 → App 不会被自动卸载，要手动拖到废纸篓。所以**能 cask 化的全部 cask 化**：Office 三件套 + Windows App 已切到 cask；`masApps` 现在只剩 `Xnip` + `iPreview`（这两个只有 MAS 分发渠道）。
- **Ghostty macOS-only** — `enable = pkgs.stdenv.isDarwin`, `package = null` (Homebrew cask). Terminfo propagated via `ghostty.terminfo` in `modules/nixos/`.
- **nix-ld on PC** — `programs.nix-ld.enable = true` in `hosts/awesome-pc/default.nix` for VSCode Remote / Cursor 等预编译二进制。
- **home-manager `backupFileExtension = "bak"`** — set in `lib/default.nix`. Existing dotfiles get `.bak` suffix on conflict.
- **mise** — runtime version management (`home/dev/languages.nix`). `trusted_config_paths` 收束到 `~/Developer` 与 `~/nix-config`；新增项目根目录时在此扩展，不要回退到 `[ "/" ]`。
- **stateVersion** — never bump `system.stateVersion` (per-host) or `home.stateVersion` (`home/default.nix`). These are migration markers, not version targets.
- **AI agent 工具走 `numtide/llm-agents.nix`** — `overlays/default.nix` 拼了 `inputs.llm-agents.overlays.default`，通过 `pkgs.llm-agents.<name>` 访问。**不要**让 `llm-agents` follows 本仓 `nixpkgs`，否则 `cache.numtide.com` 直接 miss（numtide CI 用它自锁的 nixpkgs revision 构建）。`home/dev/ai/` 已拆目录：`default.nix`（imports + `skills`）/ `claude-code.nix` / `codex.nix` / `opencode.nix`。
- **`~/.claude/settings.json` 在 `home/dev/ai/claude-code.nix`** —— 关 attribution / co-author、`permissions.defaultMode = "bypassPermissions"` + `skipDangerousModePermissionPrompt`、`effortLevel = "max"`、`ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL` 固定到具体 ID、`CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1"`、关 autoupdate / install checks / nonessential traffic。改 claude 行为或换模型只动这里。
- **OpenCode 三套 profile 在 `home/dev/ai/opencode.nix`** —— 生成到 `xdg.configFile`：(1) `opencode/opencode.json` 默认 profile；(2) `opencode-profiles/omo-claude/`；(3) `opencode-profiles/omo-gpt/`。`omoGpt = lib.recursiveUpdate omoClaude {...}`，只覆写 sisyphus/prometheus/metis + unspecified-high 这几个 agent/category 的模型，其它跟 omo-claude 走。Fish 函数 `omo` → omo-claude，`omog` → omo-gpt（`home/shell/fish.nix` 的 `programs.fish.functions`），**不是** opencode plugin，也不在 `opencode.jsonc` 里登记。
- **Playwright/browser MCP 浏览器仅 Linux 配**（`home/dev/playwright.nix`，`mkIf isLinux`）—— 装 `pkgs.chromium` 并用 `PLAYWRIGHT_MCP_*` env 指过去 + `home.activation` 预建 cache 目录，绕开 playwright 在 NixOS 自下载浏览器跑不起来。Darwin 不设，走 playwright 自带下载。
- **Channels disabled, legacy `<nixpkgs>` shimmed** — `nix.channel.enable = false`，`modules/shared/nix.nix` 把 `nix.registry.nixpkgs.flake` / `nix.nixPath` 都钉到主 `inputs.nixpkgs`（`nixos-unstable`）。darwin 那边在 `lib/default.nix` 的 `mkDarwin` 里**显式** `nixpkgs.pkgs = import inputs.nixpkgs-unstable {...}`（`nixpkgs-unstable` branch，aarch64-darwin 命中率高于 `nixos-unstable`，不是 darwin 专属，谁想跟得更快都可以用）；nix-darwin 内部 lib 仍来自主 nixpkgs（`nix-darwin.inputs.nixpkgs.follows = "nixpkgs"`），避免 registry 与 darwin lib 冲突。参考 [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config/blob/main/lib/macosSystem.nix)。Flakes 是 source of truth — 不要 `nix-channel`、不要新增 `<…>` 路径，也不要把 darwin 的 `nixpkgs.pkgs` 改回 follow 机制（会复活之前的 registry 冲突）。
- **`nixpkgs.config` / `nixpkgs.overlays` 分两处** — darwin 在 `mkDarwin` 里 `import nixpkgs-unstable {...}` 时一次性传（`config.allowUnfree` + `inputs.self.overlays.default`），所以 darwin 上**不能**再写 `nixpkgs.config`；NixOS 那边在 `modules/nixos/default.nix` 里写 `nixpkgs.config.allowUnfree` + `nixpkgs.overlays`（gateway 不导入这个文件，gateway 不需要 unfree / 自定义 overlay）。
- **Binary cache** — `modules/shared/nix.nix` 按命中率排序：`cache.nixos.org` → `nix-community` → `nixpkgs-unfree` → `cache.numtide.com`（llm-agents 产物）。`cache.garnix.io` 已于 2026-07 关停（garnix 服务并入 Shopify），不要再加回来。
- **`flake.nix` 的 `nixConfig.extra-substituters` 给首次 bootstrap 用** —— `modules/shared/nix.nix` 已写 `accept-flake-config = true`（系统级），日常 `just switch` 不再 warn。首次 bootstrap（nix.settings 还没接管）仍需 `--accept-flake-config` 或用户 `~/.config/nix/nix.conf` 写一次。**`.envrc` 用 `use flake . --accept-flake-config`**——新机器 direnv 是非交互 shell，答不了 nix 的 "trust flake config?" prompt 会**卡死**，必须自带 flag。
- **Homebrew Gatekeeper / quarantine** — `caskArgs.no_quarantine` 已被 Homebrew 在 5.0.0 强制移除（hard error，不是 deprecation）。**Decision**：不做任何自动化 quarantine 绕过 —— 不写 `system.activationScripts` 调 `xattr`、不引第三方 tap（如 `toobuntu/cask-tools`）。未公证的 cask（国产软件居多：qq/wechat/feishu/tencent-meeting/winbox/uuremote/fl-clash/cherry-studio/mos 等）首次启动被 Gatekeeper 拦下时，依赖「系统设置 → 隐私与安全 → 仍要打开」由用户人工放行。**不要**再加 `caskArgs.no_quarantine = true;`，也**不要**主动新增 xattr 脚本。
- **Homebrew fish 集成已声明式** — `homebrew.enableFishIntegration = true` 在 `modules/darwin/default.nix`。它会跑 `brew shellenv fish` 并注册 brew 补全到 `fish_complete_path`。**不要**在 fish 配置里手写 `eval (brew shellenv)`。
- **PATH 加目录用 `home.sessionPath`** — 写在 `home/shell/fish.nix`（已有 `$HOME/go/bin`、`$HOME/.bun/bin`、Darwin 下 VSCode bin）。它进 `hm-session-vars.sh`，所有 shell 与 GUI app 都生效。**不要**用 `fish_add_path` 在 `interactiveShellInit` 里加静态路径。平台特化用 `++ lib.optional pkgs.stdenv.isDarwin ...`。
- **Fish 函数走 `programs.fish.functions.<name>`** — 已有的 `op-env-refresh` / `op-env-clear` / `omo` / `omog` 都用 submodule（`body`、`description`）。**不要**把函数定义塞回 `interactiveShellInit` 字符串里。
- **平台分支在构建时，不在 shell 里** — 平台特化用 `lib.optional pkgs.stdenv.isDarwin ...` / `lib.optionalAttrs pkgs.stdenv.isLinux {...}`。**不要**写 `if uname ... end` / `if test (uname) = Darwin` 这种运行时探测。
- **`nh.flake` 已指向 `~/nix-config`** — 所以 `nh os switch` / `nh home switch` / `nh clean all` 不需要 `--flake` 参数。`programs.nh` 在 `home/default.nix`。

## Darwin hosts

### Mac mini

常开机做远程入口（SSH/Tailscale）。**FileVault 开着**，不做自动登录。从代码看不出的硬约束：

- **Location Services 关掉**：写 `/var/db/locationd/...ByHost/com.apple.locationd` 的 `LocationServicesEnabled` plist key（DISA STIG V-268480 / CIS macOS 15 L2 §2.6.1.1）。必须用 `sudo -u _locationd defaults -currentHost write ...`，否则归属不对 locationd 不读。**关 location 后自动时区也失效** → 必须显式 `time.timeZone`（`awesome-mac-mini` 写死 `Asia/Shanghai`；`awesome-macbook-air` 不写以保留出差自动切换）。
- **pmset 与 `power.*` 双保险**：`power.restartAfterPowerFailure` + `pmset -a autorestart 1` 同时写。M1 笔记本上 `systemsetup -setRestartPowerFailure` 有静默失败案例（nix-darwin#1236），pmset 兜底。Mac mini 受影响小但留着无害。
- **pmset 上不要加的两条**：(1) `pmset -a powernap 0` —— Power Nap 在 Apple Silicon 上不存在（Apple Support 原话 "only available on Intel-based Mac computers"），写了无效；(2) `pmset -a womp 1` —— 与 `networking.wakeOnLan.enable = true` 完全重复（底层都是 `systemsetup -setWakeOnNetworkAccess`）。
- **`pmset -a autopoweroff 0 / standby 0`** 必须保留：Apple Silicon Mac mini 默认会进类休眠的"假关机"，影响远程可达性。
- **Screen Sharing 不能用 launchctl 启用**：macOS 12.1+ 起 `launchctl enable system/com.apple.screensharing` + `kickstart` 都无法完整启用屏幕共享，必须手动在 System Settings → 通用 → 共享 里开。不要在 activation script 里加这种命令，纯噪音。

### MacBook Air

- **用纯 pmset 而非 `power.sleep.*` 是有意的**：后者走 `systemsetup -setComputerSleep Never` 会同时屏蔽合盖睡眠，笔记本要保留合盖能睡。不要"优化"成 nix-darwin 的高层 option。
- 共享 `modules/darwin/default.nix` 全套 + 自己加 `thaw`（刘海菜单栏，mini 没刘海所以不共享）。

## Mihomo Gateway

单臂透明代理网关（Mihomo + nftables TPROXY），**不是日用 NixOS**。从原 `imbytecat/mihomo-gateway` 仓库吸收进来后保持隔离。

### 模块边界

- **共享**：仅 `modules/shared/nix.nix`（Lix + nix.settings + flake registry/nixPath + nixpkgs.config）。**不**导入 `modules/shared/default.nix`（不要 fonts/fish/1password）、`modules/nixos/`（不要 docker/locale/user 这些日用包）、home-manager、catppuccin。
- **网关本身**：`modules/gateway/{default,constants,mihomo,tproxy}.nix` —— mihomo subscribe pipeline + nftables TPROXY + 单臂 networking (`useNetworkd`/`useDHCP=false`/`firewall.enable=false` + 50-lan 匹配 `en* eth*` + `IPv4ReversePathFilter=no`) + resolved（`DNSStubListener=no` 让 53）。
- **Host**：`hosts/mihomo-gateway/{default,disko}.nix` —— hostName/boot/disko/i18n/timezone/openssh（root-only 硬化）/stateVersion/SJTU 镜像。
- **Builder**：`mylib.mkServer`（`lib/default.nix`）—— 通用远程服务器 builder，**不是**网关专属。`username = "root"`，调用方传 `hostname` + `extraModules`，自动拉 `inputs.disko.nixosModules.disko`。加新服务器只需在 `flake.nix` 给一个新 entry，把对应 `modules/<purpose>` 与 `hosts/<host>` 放进 `extraModules`。

### 部署套路

```bash
just install <host> <remote>   # 首装；走 nixos-anywhere --build-on remote
just deploy  <host> <remote>   # 更新；走 nixos-rebuild --target-host
```

`install` 默认 `--build-on remote`（目标机自己 build），所以本机架构无所谓。`deploy` 有 [linux]/[macos] 变体，linux 本机构建后 SCP 推送（同架构最快），macos 加 `--build-host` 让目标机自己 build（避开 Mac 跨架构编译）。

首装完后 SSH host key 会变，用 `ssh-keygen -R <remote>` 清一下本地 known_hosts。

### 必守约束（改代码前必看）

详细排查见 `.agents/skills/mihomo/SKILL.md`。下面只列硬约束：

- **不要设 `routing-mark`**：nftables 只有 PREROUTING 无 OUTPUT，mihomo 出站不会被拦截；设了 ip rule 会把出站路由回本机形成黑洞。
- **使用 `tproxy-port` 而非 `listeners`**：效果相同，更简单。
- **rp_filter 必须通过 networkd 逐接口禁用**（`en* eth*` + `lo` 都要）。sysctl `all`/`default` 不足以覆盖 NixOS 默认值 2。
- **必须放开 `AF_NETLINK`**：上游 `services.mihomo` 默认只允许 `AF_INET{,6}`，会让所有 UDP DIRECT 静默失败（日志 `netlinkrib: address family not supported by protocol`）。TCP DIRECT 不受影响，所以容易漏诊。
- **不引入 BBRv3**：未进主线内核；BBR+fq 就是当前最优组合。
- IPv6 转发被 sysctl + `ip6 mihomo` forward drop 双重阻断，不要在别处"放回"。
- `modules/gateway/tproxy.nix` 的 sysctl 是最小完整集，不要再加调优项。
- `firewall.enable = false` 是有意的，nftables 规则由 `modules/gateway/tproxy.nix` 直接管理。
- `external-controller = "0.0.0.0:9090"` 是有意的，安全靠 `SECRET` 强制认证。
- **不加 hardening**（`ProtectSystem`/`PrivateTmp` 等）：单用户网关不需要，加了会和 mihomo 进程能力冲突。

### 常量

集中在 `modules/gateway/constants.nix`，被 `tproxy.nix` 和 `mihomo.nix` 直接 `import`（不是 NixOS module options）。改端口/标记只需改这一个文件。

| 常量 | 值 | 用途 |
|------|-----|------|
| `tproxyPort` | 7894 | TPROXY 监听 |
| `mixedPort` | 7890 | HTTP+SOCKS5 混合代理 |
| `dnsPort` | 1053 | Mihomo DNS |
| `routingMark` | 6666 | fwmark |
| `routingTable` | 100 | 策略路由表 |

### 订阅机制

环境变量文件：`/etc/mihomo/env`（`CONFIG_URL` + `SECRET`），首次部署时手动创建。三个 systemd 单元协作：

| 单元 | 触发 | 职责 |
|------|------|------|
| `mihomo-subscribe.path` | 监听 `/etc/mihomo/env` 变化 | 文件创建/修改即触发 |
| `mihomo-subscribe.timer` | `OnUnitActiveSec=6h` | 周期性更新 |
| `mihomo-subscribe.service` | path/timer 触发 | 下载 → 黑名单净化 → `yq load()` 合并 baseConfig → SECRET 注入 → `mihomo -t` 验证 → 备份旧配置 → 替换 → 重启 mihomo |

Fallback 配置通过 `systemd.tmpfiles.rules` 的 `C`（copy-if-absent）部署到 `config.yaml`，不走 preStart / activationScripts。

关键规则：
- 环境变量通过 systemd `EnvironmentFile=` 注入，**不要用 `source`**。
- `SECRET` 必需（缺失 `exit 1`）；`CONFIG_URL` 缺失时 `exit 0`（首次部署尚未配置）。
- 黑名单删除的键（`routing-mark`/`tun`/`listeners`/各种 port/`allow-lan`/`bind-address`/`external-controller`/`secret`）**不可由订阅覆盖**。新增黑名单项加到 subscribe 脚本的 `del()` 链。
- `fallbackConfig` 通过 `removeAttrs` 去掉 `external-controller`，保证无 SECRET 时不暴露 API。

## Environment

1Password CLI secrets are **cached locally** — shell startup reads `~/.cache/op-env/env.fish` (no network).

- Template: `home/shell/fish.nix` → `~/.config/op-env/env.tpl` (`op://` refs, safe to commit)
- Cache: `~/.cache/op-env/env.fish` (plaintext, `chmod 600`, outside git/nix store)
- Auth: `OP_SERVICE_ACCOUNT_TOKEN` in `~/.config/fish/local.fish` (gitignored)
- Refresh: user runs `op-env-refresh` manually (needs network). Atomic write (mktemp + mv), failure keeps old cache.
- Clear: `op-env-clear` removes cache file.
- `local.fish` is sourced **after** the cache, so it can override env vars per-machine.

## Home Manager option API

Use the new names:
- `programs.git.settings.user.{name,email}` (not `userName`/`userEmail`)
- `programs.git.settings.*` (not `extraConfig`)
- `programs.delta.{enable,options}` (not `programs.git.delta.*`)
- `programs.delta.enableGitIntegration = true` (must be explicit — defaults to `false`)
- `programs.ssh.settings."*"` with ssh_config-cased keys (`IdentityFile` / `AddKeysToAgent`) — **not** `matchBlocks.*` / `addKeysToAgent` (deprecated; migrated in `home/dev/ssh.nix`)
- `programs.ssh.enableDefaultConfig = false`
- **不要写 `enableFishIntegration = true;`** — HM 自 2025-02-07 起继承 `home.shell.enableShellIntegration`（默认 `true`），显式 `true` 是噪声。仅在主动关闭时写 `false`（如 `programs.zellij.enableFishIntegration = false`）。
- 装 CLI 工具时，先看是否有 `programs.<name>` 模块（如 `nh` / `fastfetch` / `tealdeer`），优先用模块而不是 `home.packages`。

## Nix tooling

- LSP: `nixd`. Formatter: `nixfmt`. Linter: `statix`.
- All in `home/dev/languages.nix`.
- `just lsp <host>` generates `.vscode/settings.json` from `.vscode/settings.base.json` (gitignored output).

## Tool usage

- `opencode.jsonc` configures `just-lsp` (LSP) and `mcp-nixos` (MCP via `uvx mcp-nixos`).
- **Always use `nixos_nix` MCP** to look up nix-darwin/NixOS/home-manager options before writing config. Don't guess option names.
- **Skills** at `.agents/skills/` (open-format Agent Skills, see https://agentskills.io)。当前只有 `mihomo/`：Mihomo CLI 速查 + TPROXY 排查手册（rp_filter / AF_NETLINK / `skb:kfree_skb` tracepoint 流程）。改 `modules/gateway/*` 前先读。

## Conventions

- Commit messages and in-file comments are written in Chinese (zh-CN). Follow conventional commits: `<type>(<scope>): <desc>` — e.g. `feat(home): 新增 yt-dlp 视频下载工具`, `docs(agents): 同步 overlay 与 nixPath shim 现状`. Match this style when adding new commits/comments.
- **注释最小化（硬规则）**：用户偏好"代码即文档"。**默认不要写注释**，包括给单个包 / option / cask 加行尾标签（如 `trzsz-ssh # tssh: 兼容 openssh 客户端`、`services.openssh = { # root-only 硬化` 这种全部禁止 —— 包名/option 名已自解释，commit message 已说明意图）。**只在**满足下列之一时才写注释：
  - **WHY 类**：从 option/cask 名字推不出的决策依据（FileVault 前置、`idleTime` 用 `-currentHost` 兜底、cyberduck `253402300799000` 那种魔法数字、`AF_NETLINK` 不放开会让 UDP DIRECT 静默挂）。
  - **踩坑 / 反直觉**：上游默认值会咬人的（rp_filter `all`/`default` 不覆盖逐接口、`pmset autopoweroff` 必须显式关、Homebrew `cleanup=zap` 会删未声明项）。
  - **跨文件耦合提示**：当前文件的设置依赖别处（如 `nftables 规则在 ./tproxy.nix 直接管理`、`# ls/la/lt 来自 programs.eza`）。

  其它情况一律删。Decision rationale 留 commit message，**别灌进文件**。 review 自己写的注释，问一句"如果这行没了，agent 会写错吗？"——答案是不会就删。
