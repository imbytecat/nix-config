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

- `lib/default.nix` — builders: `mkDarwin`, `mkNixos`, `mkHome`. All hosts get shared modules + home-manager + catppuccin.
- `modules/shared/` — both platforms: nixpkgs config, overlays, nix settings, Lix
- `modules/darwin/` — macOS: system preferences, homebrew (casks/brews/masApps), fonts, fish shell, user
- `modules/nixos/` — NixOS: base packages, docker, locale, user
- `home/` — home-manager (shared across all hosts via `useGlobalPkgs`)
- `hosts/*/` — per-host overrides (minimal; mostly `stateVersion` + Touch ID)
- `overlays/` + `pkgs/` — custom packages (comment-checker)
- `secrets/` — sops-encrypted secrets (age key derived from `~/.ssh/id_ed25519`)

Config flows: `hosts/*` (host-specific) -> `modules/*` (platform) -> `home/*` (user-level, cross-platform)

## Nix implementation

All platforms use **Lix** (`nix.package = pkgs.lix` in `modules/shared/nix.nix`). Channels are disabled (`nix.channel.enable = false`) — flakes only.

## Commands

```bash
# Justfile shortcuts (preferred)
just darwin mac-mini       # rebuild macOS host
just darwin macbook-air
just nixos                 # rebuild WSL (linux only)
just check                 # eval configs without building (platform-aware)
just update                # nix flake update
just secrets               # sops secrets/secrets.yaml
just gc                    # nix-collect-garbage -d
just show                  # nix flake show

# Direct (when just isn't available)
sudo darwin-rebuild switch --flake .#mac-mini
sudo nixos-rebuild switch --flake .#wsl
nix build .#darwinConfigurations.mac-mini.system --dry-run   # validate (eval only)
nix build .#darwinConfigurations.mac-mini.system             # validate (full build)

# First-time bootstrap (nix-darwin not yet installed)
sudo nix run nix-darwin -- switch --flake .#mac-mini
```

Fish abbreviations `rebuild` and `update` are also available in the shell (defined in `home/shell/fish.nix`). `rebuild` auto-detects the platform and derives the flake attr from hostname.

## Critical gotchas

- **catppuccin.nvim workaround active**: `catppuccin.enable = true` works, but `home/dev/neovim.nix` overrides `catppuccin.sources.nvim` to add `catppuccin.lib.detect_integrations` to `nvimSkipModule`. Upstream fix pending in catppuccin/nix. Cleanup condition: after `nix flake update`, if removing the override still builds, delete it. See `TODO.md`.
- **catppuccin module name**: Uses `catppuccin.homeModules.catppuccin` (not the old `homeManagerModules`). NixOS uses `catppuccin.nixosModules.catppuccin`.
- **Homebrew tap casks**: Casks from taps need full path (e.g. `"goooler/repo/fl-clash"`), not just the short name.
- **`onActivation.cleanup = "zap"`**: Any brew formula/cask NOT declared in `modules/darwin/default.nix` WILL be removed on rebuild. Be comprehensive.
- **Repo location**: Must be at `~/Developer/nix-config`. Fish abbreviations and `rebuild` reference this path.
- **First-time bootstrap requires sudo**: `sudo nix run nix-darwin -- switch --flake .#mac-mini` (not `darwin-rebuild` which doesn't exist yet).

## Secrets (sops-nix)

- Encrypted with age, key derived from `~/.ssh/id_ed25519` (see `.sops.yaml`)
- Secrets file: `secrets/secrets.yaml` — edit with `just secrets` (runs `sops`)
- Decrypted at runtime via `home/secrets.nix`, exposed as env vars in fish (`AI_GATEWAY_BASE_URL`, `AI_GATEWAY_API_KEY`)
- sops-nix integrated via `home-manager` shared module in `lib/default.nix`
- Never commit `*.dec.yaml`, `*.dec.json`, `*.plaintext` (in `.gitignore`)

## Shell

Fish (not zsh). All tool integrations use `enableFishIntegration`. Key files:
- `home/shell/fish.nix` — abbreviations, interactiveShellInit, dynamic `rebuild` abbr
- `home/shell/tools.nix` — fzf, atuin, zoxide (`--cmd cd`), direnv, bat, eza, yazi, btop, zellij
- `home/shell/starship.nix` — prompt

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
