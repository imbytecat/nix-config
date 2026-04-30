# AGENTS.md

## Overview

Nix flake — 3 日用设备 (Mac Mini, MacBook Air: aarch64-darwin; WSL: x86_64-linux) + 1 单臂透明代理网关 (mihomo-gateway: x86_64-linux)。日用机单用户 `imbytecat`，网关单用户 `root`。Uses **Lix**.

## Architecture

```
flake.nix
├── darwinConfigurations.mac-mini    (aarch64-darwin)
├── darwinConfigurations.macbook-air (aarch64-darwin)
├── nixosConfigurations.wsl          (x86_64-linux, 日用)
└── nixosConfigurations.gateway      (x86_64-linux, 网关，root-only，模块隔离)
```

- `lib/default.nix` — `mkDarwin`/`mkNixos`/`mkServer` builders, `sshKeys` (via `specialArgs`), `homeManagerConfig`
- `modules/shared/` — cross-platform: Lix, overlays, fonts, fish, openssh, 1password
- `modules/darwin/` — system preferences, homebrew, user
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
# 本机重建
just rebuild mac-mini       # macOS host (darwin-rebuild)
just rebuild macbook-air
just rebuild wsl            # NixOS host (nixos-rebuild)
just rebuild gateway        # 在网关本机跑（不是远程 push）

# 远程 NixOS 主机（任意 nixosConfigurations.<host> 都可，不限网关）
just install <host> <ip>    # 首装：nixos-anywhere（kexec → disko 全盘 → install → reboot）
just deploy <host> <ip>     # 更新：nixos-rebuild switch --target-host

# eval / flake
just check                  # eval all hosts (platform-aware)
just update                 # nix flake update
just up nixpkgs             # update single input
just clean                  # nix-collect-garbage -d (user-level only)
just rollback               # NixOS only — rollback to previous generation
just history                # list system profile generations
just show                   # nix flake show
just lsp mac-mini           # nixd option completion for VSCode
```

Note: `just check`、`just rebuild`、`just deploy` 都有 `[macos]`/`[linux]` 变体 —— justfile 按本机平台自动选。`install` 跨平台单一实现，因为 `--build-on remote` 让目标机自己 build。

**Mac → Linux server 注意**：`just deploy` 的 macOS 变体加 `--build-host root@<target>` 让目标机自己 build（避开 Mac 跨架构编译）；Linux 变体本机构建后 SCP 推送，同架构最快。

## Gotchas

- **Shared settings in `modules/shared/`** — don't re-declare fish/openssh/1password/fonts in platform modules.
- **`sshKeys` centralized** in `lib/default.nix` via `specialArgs`. Don't hardcode.
- **WSL aliases force-cleared** — `hosts/wsl/default.nix` uses `lib.mkForce {}`. All aliases via Home Manager only.
- **Neovim = lazyvim-nix** — `programs.lazyvim` in `home/dev/neovim.nix`. `catppuccin.nvim.enable = false` (LazyVim manages colorscheme). The `lazyvim.homeManagerModules.default` is loaded as a sharedModule in `lib/default.nix`.
- **catppuccin modules** — `catppuccin.homeModules.catppuccin` (home), `catppuccin.nixosModules.catppuccin` (NixOS). Not the old `homeManagerModules`.
- **Homebrew `cleanup = "zap"`** — undeclared casks/brews get removed. `greedyCasks = true` upgrades even auto-updating casks. Shared → `modules/darwin/default.nix`, host-specific → `hosts/*/default.nix` (e.g. `thaw` on macbook-air). Tap casks need full path (e.g. `"goooler/repo/fl-clash"`).
- **Ghostty macOS-only** — `enable = pkgs.stdenv.isDarwin`, `package = null` (Homebrew cask). Terminfo propagated via `ghostty.terminfo` in `modules/nixos/`.
- **nix-ld on WSL** — `programs.nix-ld.enable = true` for VSCode Remote.
- **home-manager `backupFileExtension = "bak"`** — set in `lib/default.nix`. Existing dotfiles get `.bak` suffix on conflict.
- **mise** — runtime version management (`home/dev/languages.nix`). `trusted_config_paths` 收束到 `~/Developer` 与 `~/nix-config`；新增项目根目录时在此扩展，不要回退到 `[ "/" ]`。
- **stateVersion** — never bump `system.stateVersion` (per-host) or `home.stateVersion` (`home/default.nix`). These are migration markers, not version targets.
- **AI agent 工具走 `numtide/llm-agents.nix`** — `overlays/default.nix` 拼了 `inputs.llm-agents.overlays.default`，通过 `pkgs.llm-agents.<name>` 访问（当前用 `opencode` + `skills`）。**不要**让 `llm-agents` follows 本仓 `nixpkgs`，否则 `cache.numtide.com` 直接 miss（numtide CI 是用它自锁的 nixpkgs revision 构建的）。omo 走 opencode 的 plugin 机制（`opencode.json` 里加 entry），不在这里装。
- **Channels disabled, legacy `<nixpkgs>` shimmed** — `nix.channel.enable = false`，`modules/shared/nix.nix` 把 `nix.registry.nixpkgs.flake` / `nix.nixPath` 都钉到主 `inputs.nixpkgs`（`nixos-unstable`）。darwin 那边在 `lib/default.nix` 的 `mkDarwin` 里**显式** `nixpkgs.pkgs = import inputs.nixpkgs-darwin {...}`（`nixpkgs-unstable`，aarch64-darwin 命中率高于 `nixos-unstable`）；nix-darwin 内部 lib 仍来自主 nixpkgs（`nix-darwin.inputs.nixpkgs.follows = "nixpkgs"`），避免 registry 与 darwin lib 冲突。参考 [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config/blob/main/lib/macosSystem.nix)。Flakes 是 source of truth — 不要 `nix-channel`、不要新增 `<…>` 路径，也不要把 darwin 的 `nixpkgs.pkgs` 改回 follow 机制（会复活之前的 registry 冲突）。
- **`nixpkgs.config` / `nixpkgs.overlays` 分两处** — darwin 在 `mkDarwin` 里 `import nixpkgs-darwin {...}` 时一次性传（`config.allowUnfree` + `inputs.self.overlays.default`），所以 darwin 上**不能**再写 `nixpkgs.config`；NixOS 那边在 `modules/nixos/default.nix` 里写 `nixpkgs.config.allowUnfree` + `nixpkgs.overlays`（gateway 不导入这个文件，gateway 不需要 unfree / 自定义 overlay）。
- **Binary cache** — `modules/shared/nix.nix` 按命中率排序：`cache.nixos.org` → `nix-community` → `nixpkgs-unfree` → `cache.numtide.com`（llm-agents 产物）→ `cache.garnix.io`。
- **Homebrew Gatekeeper / quarantine** — `caskArgs.no_quarantine` 已被 Homebrew 在 5.0.0 强制移除（hard error，不是 deprecation）。**Decision**：不做任何自动化 quarantine 绕过 —— 不写 `system.activationScripts` 调 `xattr`、不引第三方 tap（如 `toobuntu/cask-tools`）。未公证的 cask（国产软件居多：qq/wechat/feishu/tencent-meeting/winbox/uuremote/fl-clash/cherry-studio/mos 等）首次启动被 Gatekeeper 拦下时，依赖「系统设置 → 隐私与安全 → 仍要打开」由用户人工放行。**不要**再加 `caskArgs.no_quarantine = true;`，也**不要**主动新增 xattr 脚本。
- **Homebrew fish 集成已声明式** — `homebrew.enableFishIntegration = true` 在 `modules/darwin/default.nix`。它会跑 `brew shellenv fish` 并注册 brew 补全到 `fish_complete_path`。**不要**在 fish 配置里手写 `eval (brew shellenv)`。
- **PATH 加目录用 `home.sessionPath`** — 写在 `home/shell/fish.nix`（已有 `$HOME/go/bin`、`$HOME/.bun/bin`、Darwin 下 VSCode bin）。它进 `hm-session-vars.sh`，所有 shell 与 GUI app 都生效。**不要**用 `fish_add_path` 在 `interactiveShellInit` 里加静态路径。平台特化用 `++ lib.optional pkgs.stdenv.isDarwin ...`。
- **Fish 函数走 `programs.fish.functions.<name>`** — 已有的 `op-env-refresh` / `op-env-clear` / `__wt_osc9_9` 都用 submodule（`body`、`description`、`onVariable`）。**不要**把函数定义塞回 `interactiveShellInit` 字符串里。
- **平台分支在构建时，不在 shell 里** — WSL 的 `pbcopy`/`pbpaste` 用 `lib.optionalAttrs pkgs.stdenv.isLinux`，OSC 9;9 函数用 `lib.mkIf pkgs.stdenv.isLinux`。**不要**写 `if set -q WSL_DISTRO_NAME ... end` 这种运行时探测。
- **`nh.flake` 已指向 `~/nix-config`** — 所以 `nh os switch` / `nh home switch` / `nh clean all` 不需要 `--flake` 参数。`programs.nh` 在 `home/default.nix`。

## Mihomo Gateway

单臂透明代理网关（Mihomo + nftables TPROXY），**不是日用 NixOS**。从原 `imbytecat/mihomo-gateway` 仓库吸收进来后保持隔离。

### 模块边界

- **共享**：仅 `modules/shared/nix.nix`（Lix + nix.settings + flake registry/nixPath + nixpkgs.config）。**不**导入 `modules/shared/default.nix`（不要 fonts/fish/1password）、`modules/nixos/`（不要 docker/locale/user 这些日用包）、home-manager、catppuccin。
- **网关本身**：`modules/gateway/{default,constants,mihomo,tproxy}.nix` —— mihomo subscribe pipeline + nftables TPROXY + 单臂 networking (`useNetworkd`/`useDHCP=false`/`firewall.enable=false` + 50-lan 匹配 `en* eth*` + `IPv4ReversePathFilter=no`) + resolved（`DNSStubListener=no` 让 53）。
- **Host**：`hosts/mihomo-gateway/{default,disko}.nix` —— hostName/boot/disko/i18n/timezone/openssh（root-only 硬化）/stateVersion/SJTU 镜像。
- **Builder**：`mylib.mkServer`（`lib/default.nix`）—— 通用远程服务器 builder，**不是**网关专属。`username = "root"`，调用方传 `hostname` + `extraModules`，自动拉 `inputs.disko.nixosModules.disko`。加新服务器只需在 `flake.nix` 给一个新 entry，把对应 `modules/<purpose>` 与 `hosts/<host>` 放进 `extraModules`。

### 部署套路

```bash
just install <host> <ip>   # 首装；走 nixos-anywhere --build-on remote
just deploy  <host> <ip>   # 更新；走 nixos-rebuild --target-host
```

`install` 默认 `--build-on remote`（目标机自己 build），所以本机架构无所谓。`deploy` 有 [linux]/[macos] 变体，linux 本机构建后 SCP 推送（同架构最快），macos 加 `--build-host` 让目标机自己 build（避开 Mac 跨架构编译）。

首装完后 SSH host key 会变，用 `ssh-keygen -R <ip>` 清一下本地 known_hosts。

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
- `programs.ssh.matchBlocks."*".addKeysToAgent` (not top-level)
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
