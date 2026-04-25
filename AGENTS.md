# AGENTS.md

## Overview

Nix flake — 3 devices (Mac Mini, MacBook Air: aarch64-darwin; WSL: x86_64-linux). Single user `imbytecat`. Uses **Lix**.

## Architecture

```
flake.nix
├── darwinConfigurations.mac-mini    (aarch64-darwin)
├── darwinConfigurations.macbook-air (aarch64-darwin)
└── nixosConfigurations.wsl          (x86_64-linux)
```

- `lib/default.nix` — `mkDarwin`/`mkNixos` builders, `sshKeys` (via `specialArgs`), `homeManagerConfig`
- `modules/shared/` — cross-platform: Lix, overlays, fonts, fish, openssh, 1password
- `modules/darwin/` — system preferences, homebrew, user
- `modules/nixos/` — system packages, locale, docker, user
- `home/` — home-manager (shared, `useGlobalPkgs`), catppuccin
- `hosts/*/` — per-host overrides
- `overlays/` + `pkgs/` — custom packages (`comment-checker`) and `nixpkgs-master` channel-borrow overlay (see Gotchas)

Flow: `hosts/*` → `modules/*` → `home/*`

## Commands

```bash
just rebuild mac-mini       # macOS host (darwin-rebuild)
just rebuild macbook-air
just rebuild wsl            # NixOS host (nixos-rebuild)
just check                  # eval without building (platform-aware)
just update                 # nix flake update
just up nixpkgs             # update single input
just clean                  # nix-collect-garbage -d (user-level only)
just rollback               # NixOS only — rollback to previous generation
just history                # list system profile generations
just show                   # nix flake show
just lsp mac-mini           # nixd option completion for VSCode
```

Note: `just check` and `just rebuild` have `[macos]`/`[linux]` variants — the justfile auto-selects by platform.

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
- **Channel-borrow overlay in `overlays/default.nix`** — pulls select pkgs from `nixpkgs-master` input when unstable lags (currently just `opencode`). Delete the `inherit (master) ...` line once unstable catches up; don't add packages here unless unstable is actually broken/stale.
- **Channels disabled, legacy `<nixpkgs>` shimmed** — `nix.channel.enable = false`; `nix.registry.nixpkgs.flake` and `nix.nixPath` are pinned to `inputs.nixpkgs` in `modules/shared/nix.nix`, so `nix-shell -p` / `<nixpkgs>` resolve to the flake-locked channel. Flakes remain the source of truth — don't `nix-channel`, don't introduce new `<…>` paths.
- **Binary caches** — `cache.nixos.org` and `cache.garnix.io`. Configured in `modules/shared/nix.nix`.
- **Homebrew Gatekeeper / quarantine** — `caskArgs.no_quarantine` 已被 Homebrew 在 5.0.0 强制移除（hard error，不是 deprecation）。**Decision**：不做任何自动化 quarantine 绕过 —— 不写 `system.activationScripts` 调 `xattr`、不引第三方 tap（如 `toobuntu/cask-tools`）。未公证的 cask（国产软件居多：qq/wechat/feishu/tencent-meeting/winbox/uuremote/fl-clash/cherry-studio/mos 等）首次启动被 Gatekeeper 拦下时，依赖「系统设置 → 隐私与安全 → 仍要打开」由用户人工放行。**不要**再加 `caskArgs.no_quarantine = true;`，也**不要**主动新增 xattr 脚本。
- **Homebrew fish 集成已声明式** — `homebrew.enableFishIntegration = true` 在 `modules/darwin/default.nix`。它会跑 `brew shellenv fish` 并注册 brew 补全到 `fish_complete_path`。**不要**在 fish 配置里手写 `eval (brew shellenv)`。
- **PATH 加目录用 `home.sessionPath`** — 写在 `home/shell/fish.nix`（已有 `$HOME/go/bin`、`$HOME/.bun/bin`、Darwin 下 VSCode bin）。它进 `hm-session-vars.sh`，所有 shell 与 GUI app 都生效。**不要**用 `fish_add_path` 在 `interactiveShellInit` 里加静态路径。平台特化用 `++ lib.optional pkgs.stdenv.isDarwin ...`。
- **Fish 函数走 `programs.fish.functions.<name>`** — 已有的 `op-env-refresh` / `op-env-clear` / `__wt_osc9_9` 都用 submodule（`body`、`description`、`onVariable`）。**不要**把函数定义塞回 `interactiveShellInit` 字符串里。
- **平台分支在构建时，不在 shell 里** — WSL 的 `pbcopy`/`pbpaste` 用 `lib.optionalAttrs pkgs.stdenv.isLinux`，OSC 9;9 函数用 `lib.mkIf pkgs.stdenv.isLinux`。**不要**写 `if set -q WSL_DISTRO_NAME ... end` 这种运行时探测。
- **`nh.flake` 已指向 `~/nix-config`** — 所以 `nh os switch` / `nh home switch` / `nh clean all` 不需要 `--flake` 参数。`programs.nh` 在 `home/default.nix`。

## CI

- Garnix: auto-builds all flake outputs (darwinConfigurations, nixosConfigurations, packages) on push. Zero-config — just the GitHub App. Cache served from `cache.garnix.io`.

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

## Conventions

- Commit messages and in-file comments are written in Chinese (zh-CN). Follow conventional commits: `<type>(<scope>): <desc>` — e.g. `feat(home): 新增 yt-dlp 视频下载工具`, `docs(agents): 同步 overlay 与 nixPath shim 现状`. Match this style when adding new commits/comments.
