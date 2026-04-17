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
- `overlays/` + `pkgs/` — custom packages (`comment-checker`)

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
- **Homebrew `cleanup = "zap"`** — undeclared casks/brews get removed. `greedyCasks = true` upgrades even auto-updating casks. Shared → `modules/darwin/`, host-specific → `hosts/*/`. Tap casks need full path (e.g. `"goooler/repo/fl-clash"`).
- **Ghostty macOS-only** — `enable = pkgs.stdenv.isDarwin`, `package = null` (Homebrew cask). Terminfo propagated via `ghostty.terminfo` in `modules/nixos/`.
- **nix-ld on WSL** — `programs.nix-ld.enable = true` for VSCode Remote.
- **home-manager `backupFileExtension = "bak"`** — set in `lib/default.nix`. Existing dotfiles get `.bak` suffix on conflict.
- **mise** — runtime version management (`home/dev/languages.nix`). `trusted_config_paths = [ "/" ]` trusts all config files.
- **stateVersion** — never bump `system.stateVersion` (per-host) or `home.stateVersion` (`home/default.nix`). These are migration markers, not version targets.
- **Channels disabled** — `nix.channel.enable = false` in `modules/shared/nix.nix`. Flakes only; don't use `nix-channel` or `<nixpkgs>`.
- **Binary caches** — SJTU mirror is the first substituter, then `cache.garnix.io` and `nix-community.cachix.org`. Configured in `modules/shared/nix.nix`.
- **Homebrew `caskArgs.no_quarantine`** — still enabled but deprecated by Homebrew (removal 2026-09). Will need removal once all casks pass Gatekeeper.

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
- `programs.delta.enableGitIntegration = true` (must be explicit)
- `programs.ssh.matchBlocks."*".addKeysToAgent` (not top-level)
- `programs.ssh.enableDefaultConfig = false`

## Nix tooling

- LSP: `nixd`. Formatter: `nixfmt`. Linter: `statix`.
- All in `home/dev/languages.nix`.
- `just lsp <host>` generates `.vscode/settings.json` from `.vscode/settings.base.json` (gitignored output).

## Tool usage

- `opencode.jsonc` configures `just-lsp` (LSP) and `mcp-nixos` (MCP).
- **Always use `nixos_nix` MCP** to look up nix-darwin/NixOS/home-manager options before writing config. Don't guess option names.
