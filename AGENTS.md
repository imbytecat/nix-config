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

- `lib/default.nix` — builders: `mkDarwin`, `mkNixos`. All hosts get shared modules + home-manager + lazyvim-nix (as HM sharedModule). NixOS also gets `catppuccin.nixosModules.catppuccin`; home-manager imports `catppuccin.homeModules.catppuccin` directly in `home/default.nix`.
- `modules/shared/` — both platforms: nixpkgs config, overlays, nix settings, Lix
- `modules/darwin/` — macOS: system preferences, homebrew (casks/brews/masApps), fonts, fish shell, user
- `modules/nixos/` — NixOS: base packages, docker, locale, user
- `home/` — home-manager (shared across all hosts via `useGlobalPkgs`)
- `hosts/*/` — per-host overrides (mac-mini: 24/7 server with sleep disabled; macbook-air: portable)
- `overlays/` + `pkgs/` — custom packages (comment-checker)

Config flows: `hosts/*` (host-specific) -> `modules/*` (platform) -> `home/*` (user-level, cross-platform)

## Nix implementation

All platforms use **Lix** (`nix.package = pkgs.lix` in `modules/shared/nix.nix`). Channels are disabled (`nix.channel.enable = false`) — flakes only.

## Commands

```bash
# Justfile shortcuts (preferred)
just rebuild mac-mini       # rebuild macOS host (on macOS)
just rebuild macbook-air
just rebuild                # rebuild WSL (linux only, default: "wsl")
just rollback               # rollback to previous generation (linux only)
just check                  # eval configs without building (platform-aware)
just update                 # nix flake update
just up nixpkgs             # update a single flake input
just show                   # nix flake show
just clean                  # nix-collect-garbage -d (user-level only; NixOS system-level needs sudo)
just history                # list system profile generations
just lsp mac-mini           # generate .vscode/settings.json for nixd option completion

# Direct (when just isn't available)
sudo darwin-rebuild switch --flake .#mac-mini
sudo nixos-rebuild switch --flake .#wsl
nix build .#darwinConfigurations.mac-mini.system --dry-run   # validate (eval only)
nix build .#darwinConfigurations.mac-mini.system             # validate (full build)

# First-time bootstrap (nix-darwin not yet installed)
sudo nix run nix-darwin -- switch --flake .#mac-mini

# First-time bootstrap WSL (fresh NixOS-WSL has no git)
nix-shell -p git --run "git clone <repo-url> ~/nix-config"
cd ~/nix-config && sudo nixos-rebuild switch --flake .#wsl
```

## Critical gotchas

- **Neovim uses lazyvim-nix**: `programs.lazyvim` in `home/dev/neovim.nix` manages neovim via the `lazyvim-nix` flake input. Catppuccin nvim integration is explicitly disabled (`catppuccin.nvim.enable = false`) because LazyVim manages its own colorscheme. Don't try to use `catppuccin.enable` for nvim or the old `programs.neovim.plugins` approach.
- **catppuccin module name**: Home-manager uses `catppuccin.homeModules.catppuccin` (imported in `home/default.nix`). NixOS uses `catppuccin.nixosModules.catppuccin` (in `lib/default.nix`). Don't use the old `homeManagerModules` name.
- **Homebrew tap casks**: Casks from taps need full path (e.g. `"goooler/repo/fl-clash"`), not just the short name.
- **`onActivation.cleanup = "zap"`**: Any brew formula/cask NOT declared in `modules/darwin/default.nix` WILL be removed on rebuild. Be comprehensive.
- **First-time macOS bootstrap requires sudo**: `sudo nix run nix-darwin -- switch --flake .#mac-mini` (not `darwin-rebuild` which doesn't exist yet).
- **First-time WSL bootstrap needs `nix-shell -p git`**: Fresh NixOS-WSL has no `git`. Use `nix-shell -p git --run "git clone ..."` to clone, then `sudo nixos-rebuild switch`.
- **mise for version management**: Activated in `home/shell/fish.nix` via `mise activate fish | source`. Config in `home/dev/languages.nix` trusts all config paths.

## Secrets (1Password CLI)

- **Not sops-nix** — secrets are injected at shell startup via `op inject` (1Password CLI).
- Template: `home/shell/fish.nix` generates `~/.config/op-env/env.tpl` with `op://` references (safe to commit — contains no real secrets).
- Fish function `op-env` runs on interactive shell init, calling `op inject --in-file` to set env vars: `AI_GATEWAY_BASE_URL`, `AI_GATEWAY_API_KEY`, `EXA_API_KEY`, `CONTEXT7_API_KEY`.
- macOS: `programs._1password.enable = true` in `modules/darwin/default.nix`.
- WSL: aliases `op` to `op.exe` (Windows interop) in `home/shell/fish.nix`.
- Never commit `*.dec.yaml`, `*.dec.json`, `*.plaintext` (in `.gitignore`).

## Shell

Fish (not zsh). All tool integrations use `enableFishIntegration`. Key files:
- `home/shell/fish.nix` — abbreviations, interactiveShellInit, mise activation
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
- VSCode settings for nixd option completion: `just lsp <host>` (generates `.vscode/settings.json` from `.vscode/settings.base.json`)

## Tool usage

- **Always use the `nixos_nix` MCP tool** when searching for nix-darwin / NixOS / home-manager options. Query with `source=darwin/nixos/home-manager` and `type=options/packages` to find available options before writing config. Do not guess option names or value types — verify first.
