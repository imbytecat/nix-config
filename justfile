default:
    @just --list

# ─── Build ────────────────────────────────────────────────

[doc('macOS 仅构建本机系统（不激活，产 result/）')]
[macos]
[group('build')]
build host:
    nix build ".#darwinConfigurations.{{host}}.system"

[doc('NixOS 仅构建本机系统（不激活，产 result/）')]
[linux]
[group('build')]
build host:
    nix build ".#nixosConfigurations.{{host}}.config.system.build.toplevel"

[doc('macOS 本机激活')]
[macos]
[group('build')]
switch host:
    sudo darwin-rebuild switch --flake .#{{host}}

[doc('NixOS 本机激活')]
[linux]
[group('build')]
switch host:
    sudo nixos-rebuild switch --flake .#{{host}}

# 用于 kernel / dbus 实现 / initrd 等运行时切换不安全的更新
[doc('NixOS 本机仅注册下次启动 generation（需手动 reboot）')]
[linux]
[group('build')]
boot host:
    sudo nixos-rebuild boot --flake .#{{host}}

[doc('回滚到上一个 generation（仅 NixOS 本机）')]
[linux]
[group('build')]
rollback:
    sudo nixos-rebuild switch --rollback

# ─── Check / Diagnose ─────────────────────────────────────

[doc('eval 全部 darwinConfigurations，检查能否通过 evaluation')]
[macos]
[group('check')]
eval:
    @nix eval .#darwinConfigurations.mac-mini.system > /dev/null && echo "mac-mini: ok"
    @nix eval .#darwinConfigurations.macbook-air.system > /dev/null && echo "macbook-air: ok"

[doc('eval 全部 nixosConfigurations，检查能否通过 evaluation')]
[linux]
[group('check')]
eval:
    @nix eval .#nixosConfigurations.wsl.config.system.build.toplevel > /dev/null && echo "wsl: ok"
    @nix eval .#nixosConfigurations.gateway.config.system.build.toplevel > /dev/null && echo "gateway: ok"

[doc('nix flake check —— 完整 flake 健全性检查')]
[group('check')]
check:
    nix flake check --show-trace

# 列出哪些 derivation 要本地编译、哪些走 binary cache，定位 cache miss 元凶
[doc('dry-run 看 switch 会编译/下载什么（含 home-manager closure）')]
[macos]
[group('check')]
dry host:
    @nix build --dry-run \
      ".#darwinConfigurations.{{host}}.system" \
      ".#darwinConfigurations.{{host}}.config.home-manager.users.imbytecat.home.path" 2>&1 \
      | sed -E 's|/nix/store/[a-z0-9]{32}-||g'

[doc('dry-run 看 switch 会编译/下载什么')]
[linux]
[group('check')]
dry host:
    @nix build --dry-run \
      ".#nixosConfigurations.{{host}}.config.system.build.toplevel" 2>&1 \
      | sed -E 's|/nix/store/[a-z0-9]{32}-||g'

[doc('对比当前系统与 result/ 的包差异（先跑 just build <host>）')]
[group('check')]
diff:
    nvd diff /run/current-system result/

# ─── Remote ───────────────────────────────────────────────

# 警告：disko 会按 hosts/<host>/disko.nix 全盘重建，目标机数据全部丢失
# 装完 SSH host key 会变，记得 `ssh-keygen -R <remote>`
[doc('远程首装：nixos-anywhere kexec → disko 全盘 → install → reboot')]
[group('remote')]
install host remote:
    nix run github:nix-community/nixos-anywhere -- \
      --flake ".#{{host}}" \
      --target-host "root@{{remote}}" \
      --build-on remote

[doc('远程更新（NixOS 本机构建 → SCP 推送）')]
[linux]
[group('remote')]
deploy host remote:
    nixos-rebuild switch \
      --flake ".#{{host}}" \
      --target-host "root@{{remote}}" \
      --sudo \
      --use-substitutes

# 用于 kernel / dbus 实现 / initrd 等运行时切换不安全的更新
[doc('远程更新（仅注册下次启动 generation）')]
[linux]
[group('remote')]
deploy-boot host remote:
    nixos-rebuild boot \
      --flake ".#{{host}}" \
      --target-host "root@{{remote}}" \
      --sudo \
      --use-substitutes

# --build-host == --target-host：目标机自己 build，避开 Mac 跨架构编译 Linux
[doc('远程更新（macOS 跨架构，目标机自己 build）')]
[macos]
[group('remote')]
deploy host remote:
    nix run nixpkgs#nixos-rebuild -- switch \
      --flake ".#{{host}}" \
      --target-host "root@{{remote}}" \
      --build-host "root@{{remote}}" \
      --sudo \
      --use-substitutes

[doc('远程更新（macOS 跨架构，仅注册下次启动）')]
[macos]
[group('remote')]
deploy-boot host remote:
    nix run nixpkgs#nixos-rebuild -- boot \
      --flake ".#{{host}}" \
      --target-host "root@{{remote}}" \
      --build-host "root@{{remote}}" \
      --sudo \
      --use-substitutes

# ─── Flake / Nix ──────────────────────────────────────────

[doc('更新所有 flake 输入')]
[group('nix')]
update:
    nix flake update

[doc('更新单个 flake 输入')]
[group('nix')]
up input:
    nix flake update {{input}}

[doc('列出 flake 输出')]
[group('nix')]
show:
    nix flake show

[doc('查看 system profile 历史 generation（仅 NixOS 本机）')]
[group('nix')]
history:
    nix profile history --profile /nix/var/nix/profiles/system

# 比 -d 更安全：只删 7 天前的 generation，不会一次清光所有历史
[doc('GC：删除 7 天前的 generation 与未引用 store 对象')]
[group('nix')]
gc:
    nix-collect-garbage --delete-older-than 7d

[doc('打开带 nixpkgs 的 nix repl')]
[group('nix')]
repl:
    nix repl -f flake:nixpkgs

[doc('用 nixfmt 格式化所有 .nix 文件')]
[group('nix')]
fmt:
    find . -name '*.nix' -not -path './result/*' -not -path './.git/*' -exec nixfmt {} +

# ─── Tools ────────────────────────────────────────────────

[doc('给 nixd LSP 生成 options expr，让 VSCode 自动补全感知 host 配置')]
[macos]
[group('tools')]
lsp host:
    @jq --arg h "{{host}}" '."nix.serverSettings".nixd.options = {"nix-darwin":{"expr":"(builtins.getFlake (toString ./.)).darwinConfigurations.\($h).options"},"home-manager":{"expr":"(builtins.getFlake (toString ./.)).darwinConfigurations.\($h).options.home-manager.users.type.getSubOptions []"}}' .vscode/settings.base.json > .vscode/settings.json
    @echo "Generated .vscode/settings.json for {{host}}"

[doc('给 nixd LSP 生成 options expr，让 VSCode 自动补全感知 host 配置')]
[linux]
[group('tools')]
lsp host:
    @jq --arg h "{{host}}" '."nix.serverSettings".nixd.options = {"nixos":{"expr":"(builtins.getFlake (toString ./.)).nixosConfigurations.\($h).options"},"home-manager":{"expr":"(builtins.getFlake (toString ./.)).nixosConfigurations.\($h).options.home-manager.users.type.getSubOptions []"}}' .vscode/settings.base.json > .vscode/settings.json
    @echo "Generated .vscode/settings.json for {{host}}"
