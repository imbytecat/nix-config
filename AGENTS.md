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

- **Determinate Nix on macOS (tech debt)**: macOS currently runs Determinate Nix (commercial downstream). `modules/shared/nix.nix` sets `nix.enable = !pkgs.stdenv.isDarwin` — on darwin, nix-darwin does NOT manage: nix daemon, `/etc/nix/nix.conf`, nix version, `nix.settings`. All nix configuration on macOS is controlled by Determinate's `determinate-nixd`. The `nix.settings` block (flakes, warn-dirty) only applies on NixOS/WSL. **nix-darwin officially recommends Lix installer (not Determinate) as of 2025-12.** Migration to Lix would restore `nix.enable = true` and unified `nix.settings` across all 3 devices. README still references `install.determinate.systems` — update if/when migrating.
- **catppuccin.nvim disabled**: `catppuccin.nvim.enable = false` in `home/theme.nix` due to `catppuccin.lib.detect_integrations` require check failure in nixpkgs. Re-test periodically.
- **catppuccin module name**: Uses `catppuccin.homeModules.catppuccin` (not the old `homeManagerModules`).
- **Homebrew tap casks**: Casks from taps need full path in the casks list (e.g. `"goooler/repo/fl-clash"`), not just the short name.
- **`onActivation.cleanup = "zap"`**: Any brew formula/cask NOT declared in `modules/darwin/default.nix` WILL be removed on rebuild. Be comprehensive.
- **Repo location**: The repo lives at `~/Developer/nix-config`, NOT `~/.config/nix-config`. The `rebuild` fish abbreviation references `~/.config/nix-config` — symlink or update if needed.
- **First-time bootstrap requires sudo**: `sudo nix run nix-darwin -- switch --flake .#mac-mini` (not `darwin-rebuild` which doesn't exist yet).

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

## Nix installer situation (as of 2025-12)

macOS currently uses **Determinate Nix** (installed via `install.determinate.systems`). This is a commercial downstream of Nix by Determinate Systems with extras (lazy trees, parallel eval, FlakeHub).

**Why this matters**: Determinate runs its own daemon (`determinate-nixd`), conflicting with nix-darwin's native nix management. This forces `nix.enable = false` on darwin, splitting nix config across two owners:

| What | macOS (Determinate manages) | NixOS/WSL (nix-darwin manages) |
|------|---|---|
| nix daemon | `determinate-nixd` | nix-darwin |
| `/etc/nix/nix.conf` | Determinate | nix-darwin via `nix.settings` |
| flakes enabled | Determinate default | `nix.settings.experimental-features` |
| nix version | Determinate auto-update | nixpkgs pin |

**nix-darwin maintainer stance** (issue #1632, PR #1659, 2025-12): *"We explicitly recommend upstream Nix over Determinate Nix."* README now only recommends Lix installer.

**Migration path to Lix** (if/when decided):
1. `/nix/nix-installer uninstall` (Determinate's uninstaller)
2. `curl -sSf -L https://install.lix.systems/lix | sh -s -- install`
3. Remove `nix.enable` conditional in `modules/shared/nix.nix` (let it default to true)
4. `nix.settings` will then apply to all platforms
5. Update `README.md` install command
6. Lix is a community fork of Nix — same CLI (`nix build`, `nix flake`), different implementation (partial Rust rewrite, ~20-30% faster)

**Key distinction**: "Lix installer" is the install tool; "Lix" is the Nix implementation you run after. They are a package deal — using the Lix installer means running Lix (not upstream Nix).
