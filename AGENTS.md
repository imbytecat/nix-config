# AGENTS.md

## Repo Shape

- Nix flake for `awesome-macbook-air` (`aarch64-darwin`), `awesome-pc` (`x86_64-linux`), and `mihomo-gateway` (`x86_64-linux`, root-only gateway). Uses Lix.
- Flake attr, host directory, and `networking.hostName` must match exactly; `just _guard` calls `_valid` first, then compares `hostname -s` with the host argument.
- Builders live in `lib/default.nix`: `mkDarwin`, `mkNixos`, `mkServer`. System-level `specialArgs` carry `inputs`, `sshKeys`, and (daily hosts only) `username` — no `system`, so a shared system module needing a platform branch uses `pkgs.stdenv.isDarwin`/`isLinux`. `mkServer` deliberately does not pass `username`: nothing in the server closure needs one. Home Manager additionally gets `system` via `extraSpecialArgs` (`home/default.nix` gates `imports` on it, where `pkgs` would recurse).
- Desktop hosts explicitly import a platform desktop role: Darwin hosts use `modules/desktop/darwin.nix`, NixOS desktops use `modules/desktop/nixos.nix`. Headless dev NixOS hosts use `mkNixos` without any desktop module. Servers use `mkServer` (→ `modules/nixos/server.nix`) and intentionally avoid Home Manager, catppuccin, fish, 1Password, docker, unfree, and desktop modules.

## Commands

- Local activation: `just switch <host>`; hostname mismatch is refused. NixOS-only: `just boot <host>`, `just rollback`.
- Build without activating: `just build <host>`. Compare current generation: `just diff <host>` (auto-builds first). Hunt cache misses: `just dry <host>`.
- Checks: `just fmt`, `just eval`, `just check`. `just eval` only covers current-platform hosts, but eval-only cross-checks work from Linux too: `nix eval .#darwinConfigurations.<host>.system.drvPath` (building/activating Darwin still needs a Mac). Run evals sequentially — parallel `nix eval` can die on a busy eval-cache SQLite.
- Flake evals only see git-tracked files. `git add` new `.nix` files before any `nix eval`/`just build`, or you get "No such file or directory" against the store copy of the repo.
- `nix fmt` formats the whole repo via treefmt (config in `treefmt.nix`, currently nixfmt only); `just fmt` is just an alias. Do not go back to hand-assembling a file list.
- `nix flake check` (= `just check`) evaluates every host **and** runs `checks.formatting` (treefmt) + `checks.lint` (statix + deadnix). Both are expected to be clean — a warning is a regression, not background noise. `just lint` runs the linters alone.
- NixOS install/update: 首装优先从另一台机器运行 `just install <host> <remote>`（nixos-anywhere, `--build-on remote`）；Live 本机备用路径直接运行本仓 `packages.x86_64-linux.disko-install`，显式传 `--flake`、`--disk` 和 `--write-efi-boot-entries`；之后用 `just deploy <host> <remote>` / `just deploy-boot <host> <remote>`。
- `disko-install` **忽略** flake 里的 `device`，强制 CLI `--disk <name> <path>`（见上游 install-cli.nix）。`awesome-pc` 默认 by-id 在 `hosts/awesome-pc/disko.nix`；Live 对不上时只替换 CLI 设备路径。本地安装使用已提交的 hardware config；`nixos-anywhere` 会在调用端工作树生成 hardware config。
- `just install` deliberately passes **no** substituters/keys/experimental-features: nixos-anywhere defaults to `machineSubstituters=y`, which evals the target's `nix.settings.{substituters,trusted-public-keys}` and appends them to the installer's `~/.config/nix/nix.conf`, and it already puts `--extra-experimental-features 'nix-command flakes'` on every nix invocation (`src/nixos-anywhere.sh`). Do not re-add a hand-written cache list there — it silently drifts from `nix.settings`. Only `--no-substitute-on-destination` / `--no-use-machine-substituters` turn that off; `--option` does not.
- `.vscode/settings.json` is committed and static: nixd `options` mounts nixos + nix-darwin + home-manager option sets side by side (representative hosts `awesome-pc` / `awesome-macbook-air`; option *declarations* come from imported modules, so same-class hosts share them). No generation step.
- `nix develop` provides repo tools (`just`, `nixd`, `statix`, `deadnix`, `nvd`, `nix-tree`, treefmt wrapper) without relying on the host HM profile.

## Where Things Go

- `modules/shared/`: cross-platform system basics only (`nix.nix`, fonts, fish, 1Password CLI). `services.openssh.enable` is NOT here — it lives in `modules/nixos/base.nix` and `modules/darwin/default.nix` separately. Do not duplicate these in platform modules.
- `modules/darwin/default.nix`: Darwin system settings, nix-homebrew setup, taps, brews, activation. Shared GUI casks/MAS do not go here.
- `modules/nixos/` is a ladder, compose it in `lib/default.nix`, never sideways-import: `base.nix` (every NixOS host: locale default, timezone, `services.openssh.enable`, systemd-boot) → `dev.nix` (daily driver: unfree + overlays, catppuccin, user, docker, nix-ld, tailscale, base packages) → `modules/desktop/nixos.nix` (GUI). `server.nix` is the headless sibling of `dev.nix` (imports `base.nix`; SSH hardening, root-only, `nix.gc`/`optimise`, `configurationLimit`, zram, no fontconfig). A fact belongs in `base.nix` only if all three roles need it; anything role-shaped goes in `dev.nix`/`server.nix`, anything machine-shaped goes in `hosts/<host>/`. Do not put GUI apps in any of them.
- `modules/desktop/darwin.nix` / `modules/desktop/nixos.nix`: platform desktop roles, split on purpose — GUI app lists evolve independently per platform (brew/MAS vs nixpkgs), do not try to keep them aligned. `nixos.nix` also owns DE (Plasma 6 Wayland-only + SDDM), NetworkManager, fcitx5/rime, Bluetooth, and Logitech peripherals (`hardware.logitech.wireless` = Solaar only; piper/ratbagd are intentionally not installed). GPU drivers are hardware, they stay in `hosts/<host>/`. Single-host casks still go in `hosts/<host>/default.nix` (for example `thaw`).
- `home/dev/languages.nix`: shared development runtimes/tooling (`bun`, `go`, `nodejs`, `python3`, `uv`, `fvm`, `mise`, `android-tools`, LSPs, linters). `android-tools` is enough for `adb`/`fastboot`; in 2026 nixos-unstable no longer needs `programs.adb`, `adbusers`, or `android-udev-rules` because systemd 258 handles uaccess.
- `home/dev/agents/`: llm-agent packages and generated Codex/omp config. `home/ai-catalog.nix` is the single source for the AI gateway endpoint, provider identity, and model IDs/metadata (plain attrs imported directly, same pattern as `modules/gateway/constants.nix`). Models live under `providers.<family>.<nick>` (uniform schema; family names anthropic/openai/google/furtherverse are shared vocabulary written literally everywhere); adapters consume via the derived flat `models.<nick>` view (carries `provider`), `ref "<nick>"` (→ `provider/id`), or `providers.<family>` for per-family projection; codex/omp and the fish op-env template are adapters that render it — bump a model or rotate the endpoint there, not per-file. Claude Code was removed on purpose (unused); the anthropic family stays in the catalog because omp still serves it.
- Agent 配置的落法：`codex` 走 HM 的 `programs.codex`（`settings` + `skills`），`omp` 没有能用的模块（`programs.pi-coding-agent` 仍指着旧 `~/.pi/agent` 的 `settings.json`/`models.json`），继续用裸 `home.file` 写 `~/.omp/agent/*.yml`。
- ponytail（`inputs.ponytail`，`flake = false`）两处装法不同：codex 用 `skills = "${inputs.ponytail}/skills"` —— HM 的 `programs.codex.plugins` 需要可写的 plugin cache，`codex plugin add` 会往 store symlink 里写并直接 EROFS，marketplace 里只留一条 "not installed"；omp 手铺 `~/.omp/agent/skills/<name>` 加一条自己补 frontmatter 的 rule（上游那份没 frontmatter，omp 分桶要求 `alwaysApply`/`description`/`condition` 至少有一个，否则整条静默丢弃）。升级只用 `nix flake update ponytail`。

## Nix / Package Gotchas

- Darwin pkgs are imported in `mkDarwin` from `inputs.nixpkgs-unstable` with `allowUnfree` and overlays; do not add `nixpkgs.config` in Darwin modules.
- NixOS `allowUnfree` and overlays are in `modules/nixos/dev.nix`, so servers (`mkServer` → `server.nix`) have neither in their closure; do not move them into `base.nix`. `nix-ld` is part of `dev.nix` (headless remote dev needs it too), not a desktop or host concern.
- Channels are disabled. `modules/shared/nix.nix` pins registry and `nixPath` to flake `inputs.nixpkgs`; do not add `<nixpkgs>`/channel-based paths.
- `cherry-studio` comes from the pinned `nixpkgs-pnpm-pin` input (overlay `inherit`), not this repo's main nixpkgs — a workaround for pnpm-CVE cache misses. (`vue-language-server` shed insecure pnpm upstream and was moved back to main nixpkgs in 2026-07.) Do not add `permittedInsecurePackages` and do not package these by hand; when a package sheds insecure pnpm upstream, remove it from the overlay `inherit`, and delete the input once the list is empty.
- `llm-agents` is consumed via `inputs.llm-agents.packages.${system}.*` in `home/dev/agents/` (upstream recommended; no overlay — upstream dropped `overlays`). Intentionally does not follow this repo's nixpkgs; changing that will miss `cache.numtide.com`.
- Binary caches are in `modules/shared/nix.nix`; `flake.nix.nixConfig` is only bootstrap. Do not re-add `cache.garnix.io`. The two lists cannot be single-sourced — nix reads `nixConfig` as literals, so `import ./caches.nix` fails with `error: flake configuration setting 'extra-substituters' is a thunk` (verified). The CN mirror is intentionally in `nixConfig` (bootstrap paths: Live ISO `nix run --accept-flake-config`, `nix run .#nixos-anywhere`, `.envrc`) plus `hosts/mihomo-gateway` `nix.settings` (steady state + nixos-anywhere forwarding) — do not promote it to `modules/shared/nix.nix`, the daily machines keep upstream caches.
- `home.stateVersion` and per-host `system.stateVersion` are migration markers; never bump them as part of routine updates.

## Homebrew / Darwin

- Homebrew itself is declarative via `nix-homebrew` with `autoMigrate = true`, `mutableTaps = false`; bare machines should not run Homebrew install scripts manually.
- `homebrew.onActivation.cleanup = "zap"` uninstalls undeclared brews/casks including their prefs — removing a cask from the list is destructive on next switch. Darwin casks/MAS live in `modules/desktop/darwin.nix`; taps and brews stay in `modules/darwin/default.nix`; host-only casks stay under `hosts/<host>/`.
- Brew 6 requires non-official taps to be trusted. Keep `goooler/repo` and `imbytecat/tap` as `{ name = ...; trusted = true; }` and list all nix-homebrew-managed taps.
- Do not use removed Homebrew quarantine knobs (`caskArgs.no_quarantine`) or add automatic `xattr` bypass scripts; Gatekeeper exceptions are manual.
- `homebrew.enableFishIntegration = true` is required for nix-darwin Homebrew integration; do not replace it with shell `brew shellenv` snippets.
- MacBook Air intentionally uses raw `pmset`, not `power.sleep.*`, to preserve lid sleep behavior.

## Home Manager / Shell

- Prefer HM `programs.<name>` modules over `home.packages` when a module exists. Use current APIs: `programs.git.settings.*`, `programs.delta.*`, `programs.ssh.settings."*"`, and `programs.ssh.enableDefaultConfig = false`. One checked exception stays a raw package on purpose: `devenv` — the module's only added value is a fish `hook` that auto-enters/exits project shells on `cd`, which fights the direnv setup this repo already uses.
- `programs.gh` owns `~/.config/gh/config.yml`, so `gh alias set`/`gh config set` will fail against the read-only symlink — declare them in `programs.gh.settings` instead. Auth is `GH_TOKEN` from op-env, not the keyring: GitHub's API cannot authenticate with an SSH key (`--git-protocol ssh` only affects git transport), and the keyring token was the last thing forcing an interactive `gh auth login` on a fresh machine.
- Do not set HM `programs.*.enableFishIntegration = true`; HM inherits shell integration by default. Only set `false` when deliberately disabling it.
- Static PATH entries go in `home.sessionPath`, not `fish_add_path` in `interactiveShellInit`.
- Fish functions belong in `programs.fish.functions`; do not put function definitions back into `interactiveShellInit`.
- Platform branches should be Nix-time (`lib.optional`, `lib.optionalAttrs`, `pkgs.stdenv.isDarwin`/`isLinux`), not runtime `uname` checks. System-level modules should not need them at all — platform-specific config belongs in the platform module tree, not behind conditionals.
- `mise` uses the Home Manager `programs.mise` module; shell integration follows HM defaults. Keep `all_compile = false` for precompiled runtimes on NixOS, and `trusted_config_paths = [ "/" ]` intentionally trusts every mise config without prompting.
- 1Password env vars are cached in `~/.cache/op-env/env.fish`; `op-env-refresh` is manual and uses `OP_SERVICE_ACCOUNT_TOKEN` from `~/.config/fish/local.fish`.

## Mihomo Gateway

- Read `.agents/skills/mihomo/SKILL.md` before changing `modules/gateway/*`.
- Gateway business config comes only from `modules/gateway` + `hosts/mihomo-gateway`; the generic closure (`modules/nixos/server.nix` → `base.nix` → `modules/shared/nix.nix`, plus disko) is pulled in by `mkServer`. Keep it isolated from daily-user modules.
- Constants are plain attrs in `modules/gateway/constants.nix`, imported directly by `mihomo.nix` and `tproxy.nix`; do not turn them into NixOS options unless there is a real need.
- Use `tproxy-port`, not `listeners`. Do not set `routing-mark` in Mihomo config; nftables only intercepts PREROUTING and Mihomo outbound must not be routed back into itself.
- `rp_filter` must be disabled per-interface via networkd (`lo`, LAN interface patterns); sysctl `all/default` alone is insufficient.
- Keep `AF_NETLINK` in Mihomo `RestrictAddressFamilies`; without it UDP DIRECT silently fails while TCP may look fine.
- IPv6 forwarding is intentionally blocked by sysctl plus an `ip6` nftables forward chain that `reject`s (fast client fallback instead of a silent 1–3s stall). Do not re-enable casually.
- `firewall.enable = false` is intentional; nftables rules are owned by `modules/gateway/tproxy.nix`.
- `/etc/mihomo/env` (`CONFIG_URL` + `SECRET`) is written **by hand on the box, on purpose**. Do not add a nix/agenix/sops-nix/`op inject`+scp path for it — this was proposed and explicitly rejected. Everything else is declarative; this one file is not.
- Subscription flow: systemd `EnvironmentFile=` → sanitize every listener/API key out of the subscription → `mihomo -t` in an **isolated temp dir** (never the state dir: root would leave geo/cache.db root-owned and break `geo-auto-update`) → swap config → restart → `wait_healthy` → roll back to `.bak` on failure. Two non-obvious requirements: `systemctl restart` must keep `|| true` (otherwise `set -e` makes the rollback unreachable), and the health check must poll for ~10s rather than sleep once — with `RestartSec=5s` a single early `is-active` can catch a crash-looping unit mid-`activating` and call it success.
- DNS is explicitly excluded from the TPROXY rule (`th dport != 53`) so it is handled only by the `mihomo-dns` dstnat redirect. Without the exclusion it still works — mangle runs before dstnat and the NAT rewrite wins — but that is an implementation detail of TPROXY/NAT ordering, not a contract.
- `Restart = "always"` + `startLimitIntervalSec = 0` are deliberate: the gateway is a single point of failure, and systemd's default 5-starts-per-10s limit would park a crash-looping Mihomo in `failed` forever while the nftables rules keep blackholing the whole LAN. **Do not add fail-open** (tearing down the tables via `ExecStopPost`): sending every LAN packet unproxied and in plaintext through the GFW is worse than a loud outage.
- `external-controller = "0.0.0.0:9090"` is intentional and must not be narrowed to loopback: this is a single-armed gateway with no WAN interface, so the wildcard is the LAN address, the API requires `SECRET`, and the zashboard UI is used from the desktop over the LAN. Audits keep flagging this; it is a considered decision.
- No socket-buffer sysctl tuning (`net.core.rmem_max` etc.): the running kernel already provides a 4 MiB ceiling and the subscription's outbounds are ss/vless, so quic-go never runs locally and never asks for its 7 MiB. Revisit only after switching to hysteria2/tuic nodes, and only with a real warning in the journal as evidence.
- No `flock` in the subscription script: systemd already serialises jobs for a single unit, so the timer, the path unit and a manual `systemctl start` cannot overlap.
- Threat model is asymmetric and deliberate: **only the gateway is hardened** (it faces the GFW — encrypted-only DNS, no plaintext upstream, sanitized external input, sandboxed units). Daily hosts optimize for convenience; passwordless sudo, no lock-screen password, `LSQuarantine = false`, broad `mise` trust and Homebrew auto-upgrade on Darwin are accepted trade-offs, not oversights. Do not "harden" them.

## Conventions

- Commit messages and in-file comments are zh-CN Conventional Commits: `feat(scope): 描述`, `fix(scope): 描述`, etc. README and `.agents/skills/` are zh-CN; this file is English on purpose (it is agent-facing).
- Comments are rare. Add only WHY/gotcha/cross-file coupling notes an agent would likely miss; do not label obvious packages or options.
- If docs conflict with executable config (`flake.nix`, `justfile`, module imports), trust the executable source and update docs.
