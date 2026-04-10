# AGENTS.md

## Overview

Nix flake managing 3 devices: Mac Mini, MacBook Air (both aarch64-darwin via nix-darwin), and a Windows PC via NixOS-WSL (x86_64-linux). Single user `imbytecat` everywhere.

## Architecture

```
flake.nix
├── darwinConfigurations.mac-mini    (aarch64-darwin)
├── darwinConfigurations.macbook-air (aarch64-darwin)
└── nixosConfigurations.wsl          (x86_64-linux)
```

- `lib/default.nix` — builders: `mkDarwin`, `mkNixos`, `mkHome`
- `modules/shared/` — both platforms (nixpkgs config, overlays)
- `modules/darwin/` — macOS: system preferences, homebrew (casks/brews/masApps), fonts
- `modules/nixos/` — NixOS: base packages, docker, locale, user
- `home/` — home-manager (shared across all hosts via `useGlobalPkgs`)
- `overlays/` — custom packages (comment-checker)

## Critical gotchas

- **Determinate Nix on macOS**: `nix.enable = false` in `modules/shared/nix.nix` for darwin. Determinate manages the nix daemon; nix-darwin must not. `nix.settings` only applies on NixOS.
- **catppuccin.nvim disabled**: `catppuccin.nvim.enable = false` in `home/theme.nix` due to `catppuccin.lib.detect_integrations` require check failure in nixpkgs. Re-test periodically.
- **catppuccin module name**: Uses `catppuccin.homeModules.catppuccin` (not the old `homeManagerModules`).
- **Homebrew tap casks**: Casks from taps need full path in the casks list (e.g. `"goooler/repo/fl-clash"`), not just the short name.
- **`onActivation.cleanup = "zap"`**: Any brew formula/cask NOT declared in `modules/darwin/default.nix` WILL be removed on rebuild. Be comprehensive.
- **Repo location**: The repo lives at `~/Developer/nix-config`, NOT `~/.config/nix-config`. The `rebuild` fish abbreviation references `~/.config/nix-config` — symlink or update if needed.

## Commands

```bash
# Validate (eval only, fast)
nix build .#darwinConfigurations.mac-mini.system --dry-run

# Validate (actual build, catches runtime failures like require checks)
nix build .#darwinConfigurations.mac-mini.system

# First-time bootstrap (nix-darwin not yet installed)
sudo nix run nix-darwin -- switch --flake .#mac-mini

# Daily rebuild (after first bootstrap)
sudo darwin-rebuild switch --flake .#mac-mini

# WSL rebuild
sudo nixos-rebuild switch --flake .#wsl

# Update all inputs
nix flake update
```

## Shell

Fish (not zsh). All tool integrations use `enableFishIntegration`. Key files:
- `home/shell/fish.nix` — abbreviations, interactiveShellInit
- `home/shell/tools.nix` — fzf, atuin, zoxide (`--cmd cd`), direnv, bat, eza, yazi, btop

## Home Manager option API (current)

These options were renamed in recent home-manager; use the new names:
- `programs.git.settings.user.{name,email}` (not `userName`/`userEmail`)
- `programs.git.settings.*` (not `extraConfig`)
- `programs.delta.{enable,options}` (not `programs.git.delta.*`)
- `programs.delta.enableGitIntegration = true` (must be explicit)
- `programs.ssh.matchBlocks."*".addKeysToAgent` (not top-level `addKeysToAgent`)
- `programs.ssh.enableDefaultConfig = false` (set explicitly)

## Nix LSP

Uses `nixd` (not `nil`). nixd provides nixpkgs/option completion; nil does not. Installed via `home/dev/languages.nix`.

## Formatter

`nixfmt` (was `nixfmt-rfc-style`, now unified). Run: `nixfmt <file.nix>`
