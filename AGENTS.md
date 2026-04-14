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
- `overlays/` + `pkgs/` — custom packages

Flow: `hosts/*` → `modules/*` → `home/*`

## Commands

```bash
just rebuild mac-mini       # macOS host
just rebuild macbook-air
just rebuild wsl            # NixOS host
just check                  # eval without building
just update                 # nix flake update
just up nixpkgs             # update single input
just clean                  # nix-collect-garbage -d (user-level only)
just lsp mac-mini           # nixd option completion for VSCode
```

## Gotchas

- **Shared settings in `modules/shared/`** — don't re-declare fish/openssh/1password/fonts in platform modules.
- **`sshKeys` centralized** in `lib/default.nix` via `specialArgs`. Don't hardcode.
- **WSL aliases force-cleared** — `hosts/wsl/default.nix` uses `lib.mkForce {}`. All aliases via Home Manager only.
- **Neovim = lazyvim-nix** — `programs.lazyvim` in `home/dev/neovim.nix`. `catppuccin.nvim.enable = false` (LazyVim manages colorscheme).
- **catppuccin modules** — `catppuccin.homeModules.catppuccin` (home), `catppuccin.nixosModules.catppuccin` (NixOS). Not the old `homeManagerModules`.
- **Homebrew `cleanup = "zap"`** — undeclared casks/brews get removed. Shared → `modules/darwin/`, host-specific → `hosts/*/`. Tap casks need full path (e.g. `"goooler/repo/fl-clash"`).
- **Ghostty macOS-only** — `package = null` (Homebrew cask). Terminfo propagated via `ghostty.terminfo` in `modules/nixos/`.
- **nix-ld on WSL** — `programs.nix-ld.enable = true` for VSCode Remote.

## Environment

1Password CLI `op inject` at shell startup. Template in `home/shell/fish.nix` → `~/.config/op-env/env.tpl` (`op://` refs, safe to commit). Auth via `OP_SERVICE_ACCOUNT_TOKEN` in `~/.config/fish/local.fish` (gitignored).

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
- `just lsp <host>` generates `.vscode/settings.json` (gitignored).

## Tool usage

- `opencode.jsonc` configures `just-lsp` (LSP) and `mcp-nixos` (MCP).
- **Always use `nixos_nix` MCP** to look up nix-darwin/NixOS/home-manager options before writing config. Don't guess option names.
