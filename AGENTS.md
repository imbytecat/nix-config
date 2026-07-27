# AGENTS.md

## Repo Shape

- Nix flake for `awesome-macbook-air` (`aarch64-darwin`), `awesome-pc` (`x86_64-linux`), and `mihomo-gateway` (`x86_64-linux`, root-only gateway). Uses Lix.
- Flake attr, host directory, and `networking.hostName` must match exactly; `just _guard` only compares `hostname -s` with the host argument.
- Builders live in `lib/default.nix`: `mkDarwin`, `mkNixos`, `mkServer`. `sshKeys` and `username` are passed via `specialArgs`; there is no `system` specialArg — use `pkgs.stdenv.isDarwin`/`isLinux` if a shared module ever needs a platform branch.
- Desktop hosts explicitly import a platform desktop role: Darwin hosts use `modules/desktop/darwin.nix`, NixOS desktops use `modules/desktop/nixos.nix`. Headless dev NixOS hosts use `mkNixos` without any desktop module. Servers use `mkServer` and intentionally avoid Home Manager, catppuccin, fish, 1Password, docker, and desktop modules.

## Commands

- Local activation: `just switch <host>`; hostname mismatch is refused. NixOS-only: `just boot <host>`, `just rollback`.
- Build without activating: `just build <host>`. Compare current generation: `just diff <host>` (auto-builds first). Hunt cache misses: `just dry <host>`.
- Checks: `just fmt`, `just eval`, `just check`. `just eval` only covers current-platform hosts, but eval-only cross-checks work from Linux too: `nix eval .#darwinConfigurations.<host>.system.drvPath` (building/activating Darwin still needs a Mac). Run evals sequentially — parallel `nix eval` can die on a busy eval-cache SQLite.
- Flake evals only see git-tracked files. `git add` new `.nix` files before any `nix eval`/`just build`, or you get "No such file or directory" against the store copy of the repo.
- Bare `nix fmt` fails (the formatter is plain nixfmt reading stdin); always go through `just fmt`, which passes the file list.
- `statix check` has pre-existing warnings (empty patterns, repeated keys, `nix.registry` merge hint in `modules/shared/nix.nix`); don't treat them as regressions of your change.
- NixOS install/update: 首装优先从另一台机器运行 `just install <host> <remote>`（nixos-anywhere, `--build-on remote`）；Live 本机备用路径直接运行本仓 `packages.x86_64-linux.disko-install`，显式传 `--flake`、`--disk` 和 `--write-efi-boot-entries`；之后用 `just deploy <host> <remote>` / `just deploy-boot <host> <remote>`。
- `disko-install` **忽略** flake 里的 `device`，强制 CLI `--disk <name> <path>`（见上游 install-cli.nix）。`awesome-pc` 默认 by-id 在 `hosts/awesome-pc/disko.nix`；Live 对不上时只替换 CLI 设备路径。本地安装使用已提交的 hardware config；`nixos-anywhere` 会在调用端工作树生成 hardware config。
- `.vscode/settings.json` is committed and static: nixd `options` mounts nixos + nix-darwin + home-manager option sets side by side (representative hosts `awesome-pc` / `awesome-macbook-air`; option *declarations* come from imported modules, so same-class hosts share them). No generation step.
- `nix develop` provides repo tools (`just`, `nixfmt`, `nixd`, `statix`, `nvd`) without relying on the host HM profile.

## Where Things Go

- `modules/shared/`: cross-platform system basics only (`nix.nix`, fonts, fish, openssh, 1Password CLI). Do not duplicate these in platform modules.
- `modules/darwin/default.nix`: Darwin system settings, nix-homebrew setup, taps, brews, activation. Shared GUI casks/MAS do not go here.
- `modules/nixos/default.nix`: daily NixOS base (user, locale, docker, base system packages). Do not put GUI apps here.
- `modules/desktop/darwin.nix` / `modules/desktop/nixos.nix`: platform desktop roles, split on purpose — GUI app lists evolve independently per platform (brew/MAS vs nixpkgs), do not try to keep them aligned. `nixos.nix` also owns DE (Plasma 6 Wayland-only + SDDM), NetworkManager, fcitx5/rime, and Logitech peripherals (ratbagd/piper/solaar). GPU drivers are hardware, they stay in `hosts/<host>/`. Single-host casks still go in `hosts/<host>/default.nix` (for example `thaw`).
- `home/dev/languages.nix`: shared development runtimes/tooling (`bun`, `go`, `nodejs`, `python3`, `uv`, `fvm`, `mise`, `android-tools`, LSPs, linters). `android-tools` is enough for `adb`/`fastboot`; in 2026 nixos-unstable no longer needs `programs.adb`, `adbusers`, or `android-udev-rules` because systemd 258 handles uaccess.
- `home/dev/agents/`: llm-agent packages and generated OpenCode/Claude/Codex/Grok/omp config. `home/ai-catalog.nix` is the single source for the AI gateway endpoint, provider identity, and model IDs/metadata (plain attrs imported directly, same pattern as `modules/gateway/constants.nix`). Models live under `providers.<family>.<nick>` (uniform schema; family names anthropic/openai/google/furtherverse are shared vocabulary written literally everywhere); adapters consume via the derived flat `models.<nick>` view (carries `provider`), `ref "<nick>"` (→ `provider/id`), or `providers.<family>` for per-family projection; codex/opencode/claude-code/grok/omp and the fish op-env template are adapters that render it — bump a model or rotate the endpoint there, not per-file. opencode is single-config: omo is the only profile, written to `~/.config/opencode/` with the `oh-my-openagent` plugin baked in (no `OPENCODE_CONFIG_DIR` switching, no `omo` shell alias).

## Nix / Package Gotchas

- Darwin pkgs are imported in `mkDarwin` from `inputs.nixpkgs-unstable` with `allowUnfree` and overlays; do not add `nixpkgs.config` in Darwin modules.
- NixOS `allowUnfree` and overlays are in `modules/nixos/default.nix`; gateway does not import that module. `nix-ld` is part of the NixOS base (headless remote dev needs it too), not a desktop or host concern.
- Channels are disabled. `modules/shared/nix.nix` pins registry and `nixPath` to flake `inputs.nixpkgs`; do not add `<nixpkgs>`/channel-based paths.
- `cherry-studio` comes from the pinned `nixpkgs-pnpm-pin` input (overlay `inherit`), not this repo's main nixpkgs — a workaround for pnpm-CVE cache misses. (`vue-language-server` shed insecure pnpm upstream and was moved back to main nixpkgs in 2026-07.) Do not add `permittedInsecurePackages` and do not package these by hand; when a package sheds insecure pnpm upstream, remove it from the overlay `inherit`, and delete the input once the list is empty.
- `llm-agents` is consumed via `inputs.llm-agents.packages.${system}.*` in `home/dev/agents/` (upstream recommended; no overlay — upstream dropped `overlays`). Intentionally does not follow this repo's nixpkgs; changing that will miss `cache.numtide.com`.
- Binary caches are in `modules/shared/nix.nix`; `flake.nix.nixConfig` is only bootstrap. Do not re-add `cache.garnix.io`.
- `home.stateVersion` and per-host `system.stateVersion` are migration markers; never bump them as part of routine updates.

## Homebrew / Darwin

- Homebrew itself is declarative via `nix-homebrew` with `autoMigrate = true`, `mutableTaps = false`; bare machines should not run Homebrew install scripts manually.
- `homebrew.onActivation.cleanup = "zap"` uninstalls undeclared brews/casks including their prefs — removing a cask from the list is destructive on next switch. Darwin casks/MAS live in `modules/desktop/darwin.nix`; taps and brews stay in `modules/darwin/default.nix`; host-only casks stay under `hosts/<host>/`.
- Brew 6 requires non-official taps to be trusted. Keep `goooler/repo` and `imbytecat/tap` as `{ name = ...; trusted = true; }` and list all nix-homebrew-managed taps.
- Do not use removed Homebrew quarantine knobs (`caskArgs.no_quarantine`) or add automatic `xattr` bypass scripts; Gatekeeper exceptions are manual.
- `homebrew.enableFishIntegration = true` is required for nix-darwin Homebrew integration; do not replace it with shell `brew shellenv` snippets.
- MacBook Air intentionally uses raw `pmset`, not `power.sleep.*`, to preserve lid sleep behavior.

## Home Manager / Shell

- Prefer HM `programs.<name>` modules over `home.packages` when a module exists. Use current APIs: `programs.git.settings.*`, `programs.delta.*`, `programs.ssh.settings."*"`, and `programs.ssh.enableDefaultConfig = false`.
- Do not set HM `programs.*.enableFishIntegration = true`; HM inherits shell integration by default. Only set `false` when deliberately disabling it.
- Static PATH entries go in `home.sessionPath`, not `fish_add_path` in `interactiveShellInit`.
- Fish functions belong in `programs.fish.functions`; do not put function definitions back into `interactiveShellInit`.
- Platform branches should be Nix-time (`lib.optional`, `lib.optionalAttrs`, `pkgs.stdenv.isDarwin`/`isLinux`), not runtime `uname` checks. System-level modules should not need them at all — platform-specific config belongs in the platform module tree, not behind conditionals.
- `mise` uses the Home Manager `programs.mise` module; shell integration follows HM defaults. Keep `all_compile = false` for precompiled runtimes on NixOS, and `trusted_config_paths = [ "/" ]` intentionally trusts every mise config without prompting.
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
- All Markdown docs in this repo (`README.md`, `AGENTS.md`) are written in zh-CN.
- Comments are rare. Add only WHY/gotcha/cross-file coupling notes an agent would likely miss; do not label obvious packages or options.
- If docs conflict with executable config (`flake.nix`, `justfile`, module imports), trust the executable source and update docs.
