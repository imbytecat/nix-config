# AGENTS.md

## Repo Shape

- Nix flake (Lix) for six hosts. The flake attr, `hosts/<host>/` and `networking.hostName` must match exactly; `just _guard` refuses a local switch when `hostname -s` differs.

  | Host | Platform | Composition in `modules/hosts.nix` |
  |------|----------|------------------------------------|
  | `awesome-macbook-air` | aarch64-darwin | base, workstation, desktop |
  | `awesome-pc` | x86_64-linux | base, workstation, desktop + systemd-boot, single-disk |
  | `awesome-devbox` | x86_64-linux (headless) | base, workstation + grub-raid, root-ssh |
  | `homelab-server` | x86_64-linux (PVE VM) | base, server, root-ssh + qemu-guest, systemd-boot, single-disk |
  | `mihomo-gateway` | x86_64-linux (VM) | base, server, root-ssh + gateway, qemu-guest, systemd-boot, single-disk |
  | `ovh-ks-5` | x86_64-linux (OVH bare metal) | base, server, root-ssh + grub-raid |

- Dendritic layout on flake-parts: `flake.nix` only declares inputs and auto-imports every `modules/**/*.nix` as a flake-parts module; paths containing `/_` are plain data or helpers imported by path. A feature file contributes plain NixOS / nix-darwin / Home Manager modules to `aspects.<class>.<name>` and may contribute `perSystem` checks or packages next to them. `modules/flake/aspects.nix` declares the allowed names: add a name there when adding a role or adapter; a misspelled aspect fails evaluation. Aspects are deliberately not `flake.modules` (Lix warns `unknown flake output 'modules'`).
- Roles: `base` (every host of a platform), `workstation` (the `imbytecat` account and shared HM environment), `desktop` (GUI apps and integration), `server` (root-only baseline for service hosts and the gateway), `gateway`. Adapters: `root-ssh`, `qemu-guest`, `systemd-boot`, `grub-raid`, `single-disk`. Every NixOS host composes exactly one boot adapter; base is bootloader-agnostic. `hosts/<host>/` holds only machine facts: hardware config, disk device, per-machine overrides. Every host gets a generated `checks.x86_64-linux.eval-<host>`.
- Module arguments: inner modules get `inputs` and `sshKeys` through `specialArgs`, plus `username` on workstations only; root-only servers get no `username` because nothing in their closure needs one. HM gets `inputs`, `username` and `sessionEnvFile` (from `modules/secrets.nix`) through `extraSpecialArgs`, and `aiCatalog`, `agentBundles`, `gatewayProviders`, `llmAgents` through `_module.args` in `modules/agents/default.nix`. There is no `system` arg: use `pkgs.stdenv.hostPlatform.system`. Flake-level code uses the top-level flake-parts `inputs`/`config`.
- The server baseline excludes Home Manager, catppuccin, zsh, 1Password, Docker, unfree and desktop features.

## Where Things Go

- **One feature per file, placed by topic.** A feature that spans platforms or roles stays in one file and keeps platform differences in the class key, not in conditionals. A single-platform feature still goes to its topic directory (`desktop/input-method.nix`, `dev/mobile.nix`). Topic directories: `shell/`, `dev/`, `agents/`, `desktop/`, `gateway/`. Cross-cutting features sit at the top level: `nix.nix`, `users.nix`, `ssh.nix`, `secrets.nix`, `home.nix`, `catppuccin.nix`, `fonts.nix`, `1password.nix`, `tailscale.nix`.
- `modules/nixos/` and `modules/darwin/` hold only platform plumbing: role baselines (`base`, `workstation`, `server`, `desktop`), adapters, macOS defaults and Homebrew itself. `modules/flake/` holds flake plumbing: aspect names, systems, the overlay export, install tooling (`install.nix`), formatter, devShell and lint (`tooling.nix`).
- `nixos/base.nix` holds only what every NixOS role needs: disko, locale/timezone, zram and the landing CLI (curl, git, lsof, pciutils, usbutils, smartmontools); Nix settings, sshd and Ghostty terminfo come from their feature files. Server echo tools (btop, neovim, ouch) stay in `nixos/server.nix`: hoisting them into base would double-install them on workstations where HM owns the configured version.
- `nixos/desktop.nix`: Plasma 6 (Wayland-only + SDDM), NetworkManager, printing/Avahi, AppImage binfmt, Bluetooth and Solaar (piper/ratbagd intentionally absent), plus the Plasma/Konsole HM config. Linux-only HM config is written from NixOS modules through `home-manager.users.${username}` so it never reaches Darwin.
- `desktop/apps.nix` is the single GUI app list for both desktops: `both` maps each Homebrew cask to the nixpkgs attr of the same app. Apps with configuration, services or special install needs get their own feature file (`1password.nix`, `tailscale.nix`, `shell/ghostty.nix`). XWayland Qt5 apps that need fcitx env (`wechat-fcitx`, `wpsoffice-fcitx`) are wrapped in the overlay. Single-host casks/packages and GPU drivers stay in `hosts/<host>/`.
- `desktop/input-method.nix`: fcitx5 + WowType, the keyd CapsLock mapping, the HM fcitx5 files, macOS CapsLock→ABC and the `wowtype` package export.
- `dev/languages.nix`: shared runtimes and editor/agent tooling. An LSP, formatter or linter earns its place only when omp's `lsp` tool, a VS Code extension or agent shells resolve it from PATH; extensions that bundle their own server do not count (`docs/research/dev-language-tools-2026-11-15.md`). Neovim stays plain `programs.neovim`: LazyVim was removed because it was barely used.
- `dev/mobile.nix`: Android, iOS and Flutter. No Android Studio and no `androidenv`: the SDK stays mutable at `ANDROID_HOME` because AGP and Flutter download NDK/platform packages into it, and Android CLI and Flutter are pinned by each project's mise. `android-tools` covers adb/fastboot; systemd 258 uaccess replaced `programs.adb`, `adbusers` and udev rules. Emulator libraries for nix-ld are split by role (headless `libx11`, windowed set on desktops); verified 2026-11-25 on emulator 37.3.10 (104 Gradle Managed Device tests headless, windowed boot on Xvfb). Evidence: `docs/research/android-{cli,emulator}-2026-11-22.md`.
- `agents/`: read `.agents/skills/ai-agents/SKILL.md` first. Model IDs, endpoints and metadata change only in `agents/_ai-catalog.nix`.
- `gateway/` + `hosts/mihomo-gateway`: read `.agents/skills/mihomo/SKILL.md` first; its decision table records rejected proposals, so do not re-propose them. Gateway business config comes only from those two places; keep it isolated from workstation features.
- `secrets.nix` is the SOPS base. Each feature declares the `sops.secrets` it uses (`ssh.nix`: `ssh_config`; `dev/git.nix`: `tea.yml`), and `agents/t3code.nix` consumes the session env.
- Repo-local packages: `overlays/default.nix` `callPackage`s `pkgs/*` and exposes `pkgs.<name>`; `flake.packages` reuses the same attrs. Modules only consume `pkgs`; never `callPackage ../../pkgs/...` from a module.
- Do not create a Docker wrapper or aspect while its shared implementation is one native line: NixOS workstations enable Docker in `nixos/workstation.nix`, `users.nix` grants the `docker` group, root-only servers enable it in their host modules. The default Docker package carries the Compose plugin; do not add `docker-compose`. `services.tailscale.enable` follows the same pattern: `tailscale.nix` for workstations (plus the Darwin cask), host-local on servers that want it, never on `mihomo-gateway`.
- Shell longer than a few lines goes into `scripts/*.sh` (shellchecked by `just lint`) or `pkgs.writeShellApplication` (shellchecked at build time), never into `writeShellScript` or long inline just recipes.

## Commands

- Local: `just switch <host>` (refuses a hostname mismatch), `just boot <host>` and `just rollback` (NixOS), `just build <host>`, `just diff <host>` (nvd against the current generation), `just dry <host>` (cache misses).
- Remote NixOS: `just deploy <host> <remote>` / `just deploy-boot <host> <remote>`; from macOS the target builds. First install: `just install <host> <remote>` erases the target disks; read `.agents/skills/nixos-install/SKILL.md` first.
- `just check` = `nix flake check`: treefmt, `scripts/lint.sh` (actionlint, statix, deadnix, shellcheck, ruff), every host's `eval-*` drvPath check and `pi-default`. A warning is a regression, not background noise. Host checks live on x86_64-linux; on macOS use `just eval` for the darwin host.
- `just eval` prints every host's toplevel drvPath (Linux: all hosts; macOS: darwin only, because the NixOS desktop evaluation needs IFD). For a pure refactor, diff its output before and after: identical lines mean identical outputs. A move that only reorders list options (packages, Brewfile) changes drvPaths; confirm the sets with `nvd diff` or `nix-diff`, and keep order-sensitive lists (`home.sessionPath`, zsh `initContent`) identical with `lib.mkAfter`/`lib.mkOrder`.
- `just fmt` = `nix fmt`: treefmt with nixfmt, shfmt, ruff-format and `just --fmt` (config in `treefmt.nix`; Markdown is deliberately excluded). Do not hand-assemble a file list. `just lint` runs the same script as `checks.lint`.
- `nix develop` (or direnv) provides `just`, `nixd`, the linters, `sops` and the treefmt wrapper. Its `nixfmt` is treefmt's exact binary because `.vscode/settings.json` makes nixd format with bare `nixfmt`; otherwise macOS would fall back to the HM copy from `nixpkgs-unstable`. `.vscode/settings.json` is committed and static (nixd options from `awesome-pc` and `awesome-macbook-air`).
- Flake evals only see git-tracked files: `git add` new files before any `nix eval`/`just build`, or you get "No such file or directory" against the store copy. Run evals sequentially; parallel `nix eval` can die on a busy eval-cache SQLite.
- The weekly dependency workflow runs `just update`, builds `wowtype`, runs `just check`, fully builds the server closures and then auto-merges.

## Nix / Package Gotchas

- Darwin pkgs are imported in the `darwin` helper of `modules/hosts.nix` from `inputs.nixpkgs-unstable` with `allowUnfree` and overlays; do not add `nixpkgs.config` in Darwin modules.
- NixOS `allowUnfree` and overlays live in `nixos/workstation.nix`, so servers have neither in their closure; do not move them into base. `nix-ld` lives there too for prebuilt binaries on every workstation (mise runtimes, Android SDK tools, VS Code/Cursor Remote).
- Channels are disabled. `nix.nix` pins the registry and `nix.nixPath` to `inputs.nixpkgs`; do not add `<nixpkgs>` or channel paths. Keep the cross-platform `nix.nixPath` until nix-darwin migrates its `NIX_PATH` handling; the NixOS rename warning is an accepted exception.
- `llm-agents` packages are consumed directly (`llmAgents`, or `inputs.llm-agents.packages.<system>` at system level); never add an overlay, and never make it follow this repo's nixpkgs, or `cache.numtide.com` misses.
- WowType tracks the upstream `release` branch and must keep `inputs.nixpkgs.follows = "nixpkgs"` because the addon links against the system fcitx5; never add an overlay. Upstream has no binary cache, so every update compiles Rust + C++ locally, which is why CI builds `packages.x86_64-linux.wowtype` before auto-merging. Its settings live in the HM-forced `wowtype.conf`: booleans are the strings `True`/`False`, and `force = true` must stay because the settings GUI replaces the symlink.
- Binary caches live in `nix.nix`; `flake.nix` `nixConfig` is only bootstrap. They cannot be single-sourced: Nix reads `nixConfig` as literals (`import` fails with "is a thunk", verified). Do not re-add `cache.garnix.io`. The CN mirror is intentionally only in `nixConfig` (bootstrap paths: Live ISO, `nix run .#nixos-anywhere`, `.envrc`) and in `hosts/mihomo-gateway` `nix.settings`; do not promote it to `nix.nix`.
- `home.stateVersion` and `system.stateVersion` are migration markers; never bump them in routine updates. A deliberate bump targets the latest released version (currently NixOS/HM `26.05`, nix-darwin `7`), never unstable's in-flight release, because weekly updates auto-merge. Before bumping, diff every host's toplevel against the previous commit and migrate the state the changed defaults touch.

## Homebrew / Darwin

- Homebrew itself is declarative via `nix-homebrew` with `autoMigrate = true` and `mutableTaps = false`; never run Homebrew install scripts on a bare machine.
- Brew is the `brew-src` flake input (a Homebrew/brew release tag), wired into nix-homebrew with `follows`. homebrew-core adopts new bottle DSL as soon as a brew release supports it while nix-homebrew's pin lags; a stale brew fails `Homebrew bundle` with `undefined method 'manifest_sha256' for an instance of BottleSpecification`. `just update` therefore moves the tag to the latest release first, and `darwin/homebrew.nix` sets `nix-homebrew.package` with the version from this repo's lock.
- `homebrew.onActivation.cleanup = "zap"` uninstalls undeclared brews and casks including their preferences: removing a cask from a list is destructive on the next switch. Casks and brews are declared by the feature that owns them (`desktop/apps.nix`, `dev/mobile.nix`, `shell/tools.nix`, …); `darwin/homebrew.nix` keeps only Homebrew itself and the taps.
- Brew 6 requires trust for non-official taps: keep `goooler/repo` and `imbytecat/tap` as `{ name = ...; trusted = true; }` and list every nix-homebrew-managed tap.
- Do not use removed quarantine knobs (`caskArgs.no_quarantine`) or add automatic `xattr` bypass scripts; Gatekeeper exceptions are manual.
- `brew shellenv` comes from nix-homebrew's shell integrations; do not also set `homebrew.enable*Integration` or hand-write `brew shellenv`.
- `system.defaults.CustomUserPreferences` is a freeform plist type, so domains merge key by key across feature files.
- The MacBook Air uses raw `pmset`, not `power.sleep.*`, to preserve lid sleep.

## Home Manager / Shell

- Prefer HM `programs.<name>` modules over `home.packages`, with current APIs (`programs.git.settings`, `programs.delta`, `programs.ssh.settings."*"`, `programs.ssh.enableDefaultConfig = false`).
- `programs.gh` owns a read-only `~/.config/gh/config.yml`: declare aliases in `programs.gh.settings`. Auth is `GH_TOKEN` from SOPS; GitHub's API cannot authenticate with an SSH key.
- Do not set HM `programs.*.enableZshIntegration = true`; integration is inherited by default. Only set `false` deliberately.
- Static PATH entries go in `home.sessionPath` of the feature that installs the tool, not `path+=` in `initContent`.
- `.zshrc` starts with `[[ -o interactive ]] || return` (`lib.mkOrder 0`); everything below is interactive-only by design. Codex's shell snapshot sources `.zshrc` non-interactively before every agent command, so the guard keeps the snapshot small and keeps zoxide's `cd` away from tools that source `.zshrc` (details in `shell/zsh.nix`).
- Platform branches are Nix-time (`lib.optional`, `pkgs.stdenv.hostPlatform.isDarwin`), never runtime `uname` checks; system modules use class keys instead.
- Host-only HM policy lives in the host module through `home-manager.users.${username}` (for example the awesome-pc Plasma power policy). Do not gate shared HM modules on `osConfig.networking.hostName`.
- mise: `all_compile = false` for precompiled runtimes, and `trusted_config_paths = [ "/" ]` intentionally trusts every config. Projects pin their own toolchains; HM installs only what is needed outside any project plus editor/agent tooling, and `globalConfig.tools` stays empty (one-offs use `mise x`). The shims directory is in `home.sessionPath`, so non-interactive shells, SSH commands and the T3 service resolve project pins too.

## Secrets

- Workstation secrets use one SOPS recipient derived from the personal Ed25519 SSH key; `just secrets` edits `secrets/workstation.yaml`. One recipient decrypts the whole file.
- `just switch`/`boot`/`deploy` run `scripts/sops-key.sh`, which installs the derived age identity at the host's `sops.age.keyFile` (`/var/lib/sops-nix/key.txt`, root 0600) the first time; the SSH login key stays on the caller. On Linux sops restarts T3 after decryption; on Darwin the rendered env path carries the ciphertext hash because HM activates before sops-nix.
- Server-side files are hand-written on purpose and kept in 1Password: `/etc/mihomo/env`, `/etc/restic/{repository,password}` and ovh-ks-5's `/root/.ssh/id_ed25519`. Do not move them into sops-nix.

## Hosts

- `homelab-server`: PVE QEMU VM with systemd-boot, DHCP, VirtIO initrd support, QEMU guest agent, root-only access and Docker.
- `ovh-ks-5`: OVH bare metal with the grub-raid layout (RAID1 root), DHCP, SSH on 22222, root-only access, Docker and Tailscale. Backups live in `hosts/ovh-ks-5/backup.nix`, whose comments carry the design: restic over SFTP, logical PostgreSQL dumps, a failed dump still snapshots but fails the unit, and the repository is never initialized automatically. This repo is public, so the repository URL, hostnames, users and ports never enter git. Operations are in README.
- `awesome-devbox`: a second OVH KS-5 with a RAID0 root and no backup. Only SSH 22 and Tailscale's UDP port are public; services stay on loopback and reach the tailnet through `tailscale serve`. T3 runs as `imbytecat` with linger on `127.0.0.1:3773`; keep pairing and credentials under that account.
- `mihomo-gateway`: single-armed transparent proxy and the only hardened host.

## Conventions

- Commit messages and in-file comments are zh-CN Conventional Commits (`feat(scope): 描述`). README and `.agents/skills/` are zh-CN; this file is English on purpose because it is agent-facing.
- Comments are rare: only WHY, gotchas and cross-file coupling an agent would likely miss.
- Telemetry: disable it only for vendors that turn it against the user; the call rests on vendor stance, not a proven mechanism (`docs/research/agent-telemetry-2026-11-23.md`). Anthropic is treated as hostile, so every Claude Code opt-out stays on even though API traffic goes to the gateway, and single-purpose switches are set next to `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`. Ordinary usage analytics are fine: existing one-line opt-outs may stay, but never add policy files, activation scripts or wrappers for them. Turning off update checks on Nix-managed binaries is a separate, functional reason.
- The threat model is asymmetric on purpose: only the gateway is hardened. Daily hosts optimize for convenience; passwordless sudo, no lock-screen password, `LSQuarantine = false`, broad mise trust and Homebrew auto-upgrade are accepted trade-offs. Do not "harden" them.
- If docs conflict with executable config (`flake.nix`, `justfile`, module imports), trust the executable source and update the docs.
