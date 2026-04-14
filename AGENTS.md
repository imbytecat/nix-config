# AGENTS.md

## Overview

Nix flake managing 3 devices: Mac Mini, MacBook Air (both aarch64-darwin via nix-darwin), and a Windows PC via NixOS-WSL (x86_64-linux). Single user `imbytecat` everywhere. Uses **Lix** (not stock Nix).

## Architecture

```
flake.nix
├── darwinConfigurations.mac-mini    (aarch64-darwin)
├── darwinConfigurations.macbook-air (aarch64-darwin)
└── nixosConfigurations.wsl          (x86_64-linux)
```

- `lib/default.nix` — builders `mkDarwin`/`mkNixos`, shared `sshKeys` constant (passed via `specialArgs`), `homeManagerConfig` helper
- `modules/shared/` — both platforms: nix/nixpkgs settings (Lix, overlays), fonts, `programs.fish.enable`, `services.openssh.enable`, `programs._1password.enable`
- `modules/darwin/` — macOS: system preferences, homebrew (casks/brews/masApps), user
- `modules/nixos/` — NixOS: system packages, locale/timezone, docker, user
- `home/` — home-manager (shared across all hosts via `useGlobalPkgs`), catppuccin theme
- `hosts/*/` — per-host overrides (mac-mini: 24/7 server; macbook-air: portable; wsl: NixOS-WSL)
- `overlays/` + `pkgs/` — custom packages (comment-checker)

Config flows: `hosts/*` (host-specific) → `modules/*` (platform) → `home/*` (user-level, cross-platform)

## Commands

```bash
# Justfile shortcuts (preferred)
just rebuild mac-mini       # rebuild macOS host
just rebuild macbook-air
just rebuild                # rebuild WSL (linux default)
just rollback               # rollback to previous generation (linux only)
just check                  # eval configs without building (platform-aware)
just update                 # nix flake update
just up nixpkgs             # update a single flake input
just clean                  # nix-collect-garbage -d (user-level only)
just lsp mac-mini           # generate .vscode/settings.json for nixd option completion

# Direct
sudo darwin-rebuild switch --flake .#mac-mini
sudo nixos-rebuild switch --flake .#wsl

# First-time macOS bootstrap (nix-darwin not yet installed)
sudo nix run nix-darwin -- switch --flake .#mac-mini

# First-time WSL bootstrap (fresh NixOS-WSL has no git)
nix-shell -p git --run "git clone <repo-url> ~/nix-config"
cd ~/nix-config && sudo nixos-rebuild switch --flake .#wsl
```

## Critical gotchas

- **Shared settings live in `modules/shared/`**: Fish, openssh, 1password, fonts, nix settings are enabled once in shared — don't re-declare in platform modules.
- **SSH keys are centralized**: Defined as `sshKeys` in `lib/default.nix`, passed via `specialArgs`. Don't hardcode keys in platform modules.
- **NixOS default shell aliases are force-cleared**: `hosts/wsl/default.nix` sets `environment.shellAliases = lib.mkForce {}` to remove NixOS defaults (`l`, `ll`, `ls`). All shell aliases are managed exclusively by Home Manager (eza integration + `fish.nix`). Don't set `environment.shellAliases` in NixOS modules — it would be ignored anyway.
- **Neovim uses lazyvim-nix**: `programs.lazyvim` in `home/dev/neovim.nix` manages neovim via the `lazyvim-nix` flake input (loaded as `sharedModules` in `lib/default.nix`). Catppuccin nvim integration is explicitly disabled (`catppuccin.nvim.enable = false`) because LazyVim manages its own colorscheme.
- **catppuccin module names**: Home-manager uses `catppuccin.homeModules.catppuccin` (in `home/default.nix`). NixOS uses `catppuccin.nixosModules.catppuccin` (in `lib/default.nix`). Don't use the old `homeManagerModules` name.
- **Homebrew `cleanup = "zap"`**: Any brew formula/cask NOT declared in `modules/darwin/default.nix` WILL be removed on rebuild. Be comprehensive. Casks from taps need full path (e.g. `"goooler/repo/fl-clash"`).
- **mise for version management**: Configured via `programs.mise` in `home/dev/languages.nix`. Config trusts all config paths (`trusted_config_paths = [ "/" ]`).
- **Ghostty is macOS-only**: `programs.ghostty.enable = pkgs.stdenv.isDarwin` with `package = null` (installed via Homebrew cask). Terminfo is propagated to NixOS via `ghostty.terminfo` in `modules/nixos/default.nix`.

## Secrets (1Password CLI)

- **Not sops-nix** — secrets are injected at shell startup via `op inject` (1Password CLI).
- Template: `home/shell/fish.nix` generates `~/.config/op-env/env.tpl` with `op://` references (safe to commit).
- Fish function `op-env` runs on interactive shell init, calling `op inject --in-file` to set env vars.
- Auth via `OP_SERVICE_ACCOUNT_TOKEN` env var (set in `~/.config/fish/local.fish`, which is gitignored via `local.fish` in `conf.d`).

## Shell

Fish (not zsh). All tool integrations use `enableFishIntegration`. Key files:
- `home/shell/fish.nix` — abbreviations, aliases, interactiveShellInit, 1Password `op-env`
- `home/shell/tools.nix` — fzf, atuin, zoxide (`--cmd cd`), direnv, bat, eza (`enableFishIntegration = true` provides `ls`/`ll`/`la`/`lt`/`lla` aliases; `fish.nix` overrides `ll`/`lla`), yazi, btop, zellij
- `home/shell/starship.nix` — prompt
- `home/shell/ghostty.nix` — Ghostty terminal config (macOS only)

## Home Manager option API

These options were renamed in recent home-manager; use the new names:
- `programs.git.settings.user.{name,email}` (not `userName`/`userEmail`)
- `programs.git.settings.*` (not `extraConfig`)
- `programs.delta.{enable,options}` (not `programs.git.delta.*`)
- `programs.delta.enableGitIntegration = true` (must be explicit)
- `programs.ssh.matchBlocks."*".addKeysToAgent` (not top-level `addKeysToAgent`)
- `programs.ssh.enableDefaultConfig = false` (set explicitly)

## Nix LSP & formatter

- LSP: `nixd` (not `nil`). Provides nixpkgs/option completion.
- Formatter: `nixfmt`. Run: `nixfmt <file.nix>`
- Both installed via `home/dev/languages.nix`.
- VSCode settings for nixd option completion: `just lsp <host>` (generates `.vscode/settings.json` from `.vscode/settings.base.json`; the generated file is gitignored).

## Tool usage

- **Always use the `nixos_nix` MCP tool** when searching for nix-darwin / NixOS / home-manager options. Query with `source=darwin/nixos/home-manager` and `type=options/packages` to find available options before writing config. Do not guess option names or value types — verify first.
