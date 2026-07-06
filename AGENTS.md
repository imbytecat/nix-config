# AGENTS.md

## Repo Shape

- Nix flake for `awesome-mac-mini`/`awesome-macbook-air` (`aarch64-darwin`), `awesome-pc` (`x86_64-linux`), and `mihomo-gateway` (`x86_64-linux`, root-only gateway). Uses Lix.
- Flake attr, host directory, and `networking.hostName` must match exactly; `just _guard` only compares `hostname -s` with the host argument.
- Builders live in `lib/default.nix`: `mkDarwin`, `mkNixos`, `mkServer`. `sshKeys` and `username` are passed via `specialArgs`; there is no `system` specialArg — use `pkgs.stdenv.isDarwin`/`isLinux` if a shared module ever needs a platform branch.
- Desktop hosts explicitly import a platform desktop role: Darwin hosts use `modules/desktop/darwin.nix`, NixOS desktops use `modules/desktop/nixos.nix`. Headless dev NixOS hosts use `mkNixos` without any desktop module. Servers use `mkServer` and intentionally avoid Home Manager, catppuccin, fish, 1Password, docker, and desktop modules.

## Commands

- Local activation: `just switch <host>`; hostname mismatch is refused. NixOS-only: `just boot <host>`, `just rollback`.
- Build without activating: `just build <host>`. Compare current generation: `just diff <host>`.
- Checks: `just fmt`, `just eval`, `just check`. On Darwin, `just check` may need a Linux remote builder because it checks NixOS configs too; use `just eval` for current-platform sanity.
- Remote NixOS install/update: `just install <host> <remote>` (nixos-anywhere, disko wipes target disk, `--build-on remote`), `just deploy <host> <remote>`, `just deploy-boot <host> <remote>`.
- `just lsp <host>` regenerates `.vscode/settings.json` for nixd option completion; output is gitignored.
- `nix develop` provides repo tools (`just`, `jq`, `nixfmt`, `nixd`, `statix`, `nvd`) without relying on the host HM profile.

## Where Things Go

- `modules/shared/`: cross-platform system basics only (`nix.nix`, fonts, fish, openssh, 1Password CLI). Do not duplicate these in platform modules.
- `modules/darwin/default.nix`: Darwin system settings, nix-homebrew setup, taps, brews, activation. Shared GUI casks/MAS do not go here.
- `modules/nixos/default.nix`: daily NixOS base (user, locale, docker, base system packages). Do not put GUI apps here.
- `modules/desktop/darwin.nix` / `modules/desktop/nixos.nix`: platform desktop roles, split on purpose — GUI app lists evolve independently per platform (brew/MAS vs nixpkgs), do not try to keep them aligned. `nixos.nix` also owns DE (Plasma 6 Wayland-only + SDDM), NetworkManager, fcitx5/rime, and Logitech peripherals (ratbagd/piper/solaar). GPU drivers are hardware, they stay in `hosts/<host>/`. Single-host casks still go in `hosts/<host>/default.nix` (for example `thaw`).
- `home/dev/languages.nix`: shared development runtimes/tooling (`bun`, `go`, `nodejs`, `python3`, `uv`, `fvm`, `proto`, `android-tools`, LSPs, linters). `android-tools` is enough for `adb`/`fastboot`; in 2026 nixos-unstable no longer needs `programs.adb`, `adbusers`, or `android-udev-rules` because systemd 258 handles uaccess.
- `home/dev/ai/`: llm-agent packages and generated OpenCode/Claude/Codex config. `opencode.jsonc` only declares `just-lsp` and the `mcp-nixos` server (`uvx mcp-nixos`).

## Nix / Package Gotchas

- Always use the `nixos_nix` MCP before adding/changing NixOS, nix-darwin, Home Manager, nixpkgs package, Nixvim, channel, or cache config. Do not guess option names.
- Darwin pkgs are imported in `mkDarwin` from `inputs.nixpkgs-unstable` with `allowUnfree` and overlays; do not add `nixpkgs.config` in Darwin modules.
- NixOS `allowUnfree` and overlays are in `modules/nixos/default.nix`; gateway does not import that module. `nix-ld` is part of the NixOS base (headless remote dev needs it too), not a desktop or host concern.
- Channels are disabled. `modules/shared/nix.nix` pins registry and `nixPath` to flake `inputs.nixpkgs`; do not add `<nixpkgs>`/channel-based paths.
- `cherry-studio` comes from the pinned `nixpkgs-cherry-studio` input (overlay `inherit`), not this repo's main nixpkgs: newer revisions mark build-time pnpm 10.29.2 insecure (CVE) and hydra stops caching it; stable's 1.7.9 depends on insecure electron-38. Do not add `permittedInsecurePackages` and do not package it by hand; delete the pinned input once nixpkgs ships cherry-studio with electron-builder >= 26.8.2.
- `llm-agents` intentionally does not follow this repo's nixpkgs; changing that will miss `cache.numtide.com`.
- Binary caches are in `modules/shared/nix.nix`; `flake.nix.nixConfig` is only bootstrap. Do not re-add `cache.garnix.io`.
- `home.stateVersion` and per-host `system.stateVersion` are migration markers; never bump them as part of routine updates.

## Homebrew / Darwin

- Homebrew itself is declarative via `nix-homebrew` with `autoMigrate = true`, `mutableTaps = false`; bare machines should not run Homebrew install scripts manually.
- `homebrew.cleanup = "zap"` removes undeclared brews/casks. Darwin casks/MAS live in `modules/desktop/darwin.nix`; taps and brews stay in `modules/darwin/default.nix`; host-only casks stay under `hosts/<host>/`.
- Brew 6 requires non-official taps to be trusted. Keep `goooler/repo` and `imbytecat/tap` as `{ name = ...; trusted = true; }` and list all nix-homebrew-managed taps.
- Do not use removed Homebrew quarantine knobs (`caskArgs.no_quarantine`) or add automatic `xattr` bypass scripts; Gatekeeper exceptions are manual.
- `homebrew.enableFishIntegration = true` is required for nix-darwin Homebrew integration; do not replace it with shell `brew shellenv` snippets.
- Mac mini intentionally has always-on power/location-service tweaks. MacBook Air intentionally uses raw `pmset`, not `power.sleep.*`, to preserve lid sleep behavior.

## Home Manager / Shell

- Prefer HM `programs.<name>` modules over `home.packages` when a module exists. Use current APIs: `programs.git.settings.*`, `programs.delta.*`, `programs.ssh.settings."*"`, and `programs.ssh.enableDefaultConfig = false`.
- Do not set HM `programs.*.enableFishIntegration = true`; HM inherits shell integration by default. Only set `false` when deliberately disabling it.
- Static PATH entries go in `home.sessionPath`, not `fish_add_path` in `interactiveShellInit`.
- Fish functions belong in `programs.fish.functions`; do not put function definitions back into `interactiveShellInit`.
- Platform branches should be Nix-time (`lib.optional`, `lib.optionalAttrs`, `pkgs.stdenv.isDarwin`/`isLinux`), not runtime `uname` checks. System-level modules should not need them at all — platform-specific config belongs in the platform module tree, not behind conditionals.
- `proto` is installed as a package plus `proto activate fish --no-shim`; do not add `~/.proto/shims` globally or symlink `~/.proto` into the store.
- 1Password env vars are cached in `~/.cache/op-env/env.fish`; `op-env-refresh` is manual and uses `OP_SERVICE_ACCOUNT_TOKEN` from `~/.config/fish/local.fish`.

## Mihomo Gateway

- Read `.agents/skills/mihomo/SKILL.md` before changing `modules/gateway/*`.
- Gateway imports only `modules/shared/nix.nix`, `modules/gateway`, and `hosts/mihomo-gateway`; keep it isolated from daily-user modules.
- Constants are plain attrs in `modules/gateway/constants.nix`, imported directly by `mihomo.nix` and `tproxy.nix`; do not turn them into NixOS options unless there is a real need.
- Use `tproxy-port`, not `listeners`. Do not set `routing-mark` in Mihomo config; nftables only intercepts PREROUTING and Mihomo outbound must not be routed back into itself.
- `rp_filter` must be disabled per-interface via networkd (`lo`, LAN interface patterns); sysctl `all/default` alone is insufficient.
- Keep `AF_NETLINK` in Mihomo `RestrictAddressFamilies`; without it UDP DIRECT silently fails while TCP may look fine.
- IPv6 forwarding is intentionally blocked by sysctl plus an `ip6` nftables forward-drop chain. Do not re-enable casually.
- `firewall.enable = false` is intentional; nftables rules are owned by `modules/gateway/tproxy.nix`.
- `/etc/mihomo/env` provides `CONFIG_URL` and required `SECRET`; subscription updates use systemd `EnvironmentFile=`, sanitize subscription keys, validate with `mihomo -t`, then restart Mihomo.

## Conventions

- Commit messages and in-file comments are zh-CN Conventional Commits: `feat(scope): 描述`, `fix(scope): 描述`, etc.
- Comments are rare. Add only WHY/gotcha/cross-file coupling notes an agent would likely miss; do not label obvious packages or options.
- If docs conflict with executable config (`flake.nix`, `justfile`, module imports), trust the executable source and update docs.
