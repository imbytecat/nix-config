default:
    @just --list

# ─── Helpers (private) ────────────────────────────────────

# 拦 host 名 shell 元字符 / 异常 attrpath（{{quote()}} 保证不被注入到下游脚本）
_valid host:
    @bash -euc '[[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "invalid host name: $1" >&2; exit 1; }' _ {{ quote(host) }}

# remote 比 host 多允许点 (FQDN/IP) 与冒号 (IPv6-ish)
_valid_remote remote:
    @bash -euc '[[ "$1" =~ ^[a-zA-Z0-9_.:-]+$ ]] || { echo "invalid remote: $1" >&2; exit 1; }' _ {{ quote(remote) }}

# flake attr 与 hostname 现在一致，guard 直接拿 hostname -s 对比，无需 nix eval
_guard host: (_valid host)
    #!/usr/bin/env bash
    set -euo pipefail
    actual="$(hostname -s)"
    if [ "$actual" != "{{ host }}" ]; then
      echo "refuse: hostname=$actual != host={{ host }}" >&2
      exit 1
    fi

# ─── Build ────────────────────────────────────────────────

[doc('构建 {{host}} 配置（不激活，产 result/）')]
[macos]
[group('build')]
build host: (_valid host)
    nix build ".#darwinConfigurations.{{ host }}.system"

[doc('构建 {{host}} 配置（不激活，产 result/）')]
[linux]
[group('build')]
build host: (_valid host)
    nix build ".#nixosConfigurations.{{ host }}.config.system.build.toplevel"

[doc('用 {{host}} 配置激活本机（hostname 不匹配会拒绝）')]
[macos]
[group('build')]
switch host: (_guard host)
    sudo darwin-rebuild switch --flake .#{{ host }}

[doc('用 {{host}} 配置激活本机（hostname 不匹配会拒绝）')]
[linux]
[group('build')]
switch host: (_guard host)
    sudo nixos-rebuild switch --flake .#{{ host }}

# 用于 kernel / dbus 实现 / initrd 等运行时切换不安全的更新
[doc('用 {{host}} 配置注册下次启动 generation，不激活（hostname 不匹配会拒绝）')]
[linux]
[group('build')]
boot host: (_guard host)
    sudo nixos-rebuild boot --flake .#{{ host }}

[doc('回滚到上一个 generation（NixOS 本机）')]
[linux]
[group('build')]
rollback:
    sudo nixos-rebuild switch --rollback

# ─── Check / Diagnose ─────────────────────────────────────

[doc('eval 全部 darwinConfigurations 的 system derivation（跨平台需 remote builder）')]
[macos]
[group('check')]
eval:
    @nix eval .#darwinConfigurations.awesome-mac-mini.system > /dev/null && echo "awesome-mac-mini: ok"
    @nix eval .#darwinConfigurations.awesome-macbook-air.system > /dev/null && echo "awesome-macbook-air: ok"

[doc('eval 全部 nixosConfigurations 的 system toplevel（跨平台需 remote builder）')]
[linux]
[group('check')]
eval:
    @nix eval .#nixosConfigurations.awesome-pc.config.system.build.toplevel > /dev/null && echo "awesome-pc: ok"
    @nix eval .#nixosConfigurations.mihomo-gateway.config.system.build.toplevel > /dev/null && echo "mihomo-gateway: ok"

[doc('nix flake check —— 完整 flake 健全性检查（darwin 跑会触发 NixOS host eval，需要 Linux remote builder，否则用 just eval 检查本平台）')]
[group('check')]
check:
    nix flake check --show-trace

# 列出哪些 derivation 要本地编译、哪些走 binary cache，定位 cache miss 元凶
[doc('dry-run 看 {{host}} 配置会编译/下载什么（含 home-manager closure，仅本平台 host）')]
[macos]
[group('check')]
dry host: (_valid host)
    @nix build --dry-run \
      ".#darwinConfigurations.{{ host }}.system" \
      ".#darwinConfigurations.{{ host }}.config.home-manager.users.imbytecat.home.path" 2>&1 \
      | sed -E 's|/nix/store/[a-z0-9]{32}-||g'

[doc('dry-run 看 {{host}} 配置会编译/下载什么（仅本平台 host）')]
[linux]
[group('check')]
dry host: (_valid host)
    @nix build --dry-run \
      ".#nixosConfigurations.{{ host }}.config.system.build.toplevel" 2>&1 \
      | sed -E 's|/nix/store/[a-z0-9]{32}-||g'

# 自动 build 保证 result/ 跟参数对得上，再做差异比较
[doc('对比本机 /run/current-system 与 {{host}} 配置 build 结果（自动 build，hostname 不匹配会拒绝）')]
[group('check')]
diff host: (_guard host) (build host)
    nvd diff /run/current-system result/

# ─── Remote ───────────────────────────────────────────────

# 警告：disko 会按 hosts/<host>/disko.nix 全盘重建，目标机数据全部丢失
# 装完 SSH host key 会变，记得 `ssh-keygen -R <remote>`
[doc('远程首装：nixos-anywhere kexec → disko 全盘 → install → reboot')]
[group('remote')]
install host remote: (_valid host) (_valid_remote remote)
    #!/usr/bin/env bash
    set -euo pipefail
    hardware_config="./hosts/{{ host }}/hardware-configuration.nix"
    hardware_args=()
    if [ -f "$hardware_config" ]; then
      hardware_args+=(--generate-hardware-config nixos-generate-config "$hardware_config")
    fi
    nix_options=(
      --option extra-substituters "https://nix-community.cachix.org https://nixpkgs-unfree.cachix.org https://cache.numtide.com https://catppuccin.cachix.org"
      --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs= niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g= catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
    )
    nix run github:nix-community/nixos-anywhere -- \
      "${hardware_args[@]}" \
      "${nix_options[@]}" \
      --flake ".#{{ host }}" \
      --target-host "root@{{ remote }}" \
      --build-on remote

[doc('远程更新（同架构，本机构建后 SCP 推送）')]
[linux]
[group('remote')]
deploy host remote: (_valid host) (_valid_remote remote)
    nixos-rebuild switch \
      --flake ".#{{ host }}" \
      --target-host "root@{{ remote }}" \
      --sudo \
      --use-substitutes

# 用于 kernel / dbus 实现 / initrd 等运行时切换不安全的更新
[doc('远程更新（同架构，仅注册下次启动 generation）')]
[linux]
[group('remote')]
deploy-boot host remote: (_valid host) (_valid_remote remote)
    nixos-rebuild boot \
      --flake ".#{{ host }}" \
      --target-host "root@{{ remote }}" \
      --sudo \
      --use-substitutes

# --build-host == --target-host：目标机自己 build，避开本机跨架构编译
# --no-reexec：macOS 无法 exec target 的 linux nixos-rebuild，显式跳过这一步
[doc('远程更新（跨架构，目标机自己 build）')]
[macos]
[group('remote')]
deploy host remote: (_valid host) (_valid_remote remote)
    nix run nixpkgs#nixos-rebuild -- switch \
      --flake ".#{{ host }}" \
      --target-host "root@{{ remote }}" \
      --build-host "root@{{ remote }}" \
      --sudo \
      --use-substitutes \
      --no-reexec

[doc('远程更新（跨架构，仅注册下次启动 generation）')]
[macos]
[group('remote')]
deploy-boot host remote: (_valid host) (_valid_remote remote)
    nix run nixpkgs#nixos-rebuild -- boot \
      --flake ".#{{ host }}" \
      --target-host "root@{{ remote }}" \
      --build-host "root@{{ remote }}" \
      --sudo \
      --use-substitutes \
      --no-reexec

# ─── Flake / Nix ──────────────────────────────────────────

[doc('更新所有 flake 输入')]
[group('nix')]
update:
    nix flake update

[doc('更新单个 flake 输入')]
[group('nix')]
up input: (_valid input)
    nix flake update {{ input }}

[doc('列出 flake 输出')]
[group('nix')]
show:
    nix flake show

[doc('查看 system profile 历史 generation（NixOS 本机）')]
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

[doc('用 nix fmt 格式化所有 .nix 文件')]
[group('nix')]
fmt:
    nix fmt -- $(find . -name '*.nix' -not -path './result/*' -not -path './.git/*')

# ─── Tools ────────────────────────────────────────────────

# 自动探测 host 属于 darwin / nixos，以及是否含 home-manager（server 类不含）
[doc('给 nixd LSP 生成 options expr，让 VSCode 自动补全感知 {{host}} 配置')]
[group('tools')]
lsp host: (_valid host)
    #!/usr/bin/env bash
    set -euo pipefail

    # hasAttr 走懒求值，比直接 nix eval host attr 便宜
    if [ "$(nix eval ".#darwinConfigurations" --apply 'builtins.hasAttr "{{ host }}"' 2>/dev/null)" = "true" ]; then
      SET=darwinConfigurations
      KEY=nix-darwin
    elif [ "$(nix eval ".#nixosConfigurations" --apply 'builtins.hasAttr "{{ host }}"' 2>/dev/null)" = "true" ]; then
      SET=nixosConfigurations
      KEY=nixos
    else
      echo "unknown host: {{ host }}" >&2
      exit 1
    fi

    HAS_HM=false
    if nix eval ".#${SET}.{{ host }}.options.home-manager" --apply 'x: true' >/dev/null 2>&1; then
      HAS_HM=true
    fi

    jq --arg h "{{ host }}" --arg set "$SET" --arg key "$KEY" --argjson hm "$HAS_HM" '
      def base($suffix): ("(builtins.getFlake (toString ./.))." + $set + "." + $h + ".options" + $suffix);
      ."nix.serverSettings".nixd.options = (
        { ($key): {"expr": base("")} }
        + (if $hm then {"home-manager": {"expr": base(".home-manager.users.type.getSubOptions []")}} else {} end)
      )' .vscode/settings.base.json > .vscode/settings.json

    echo "Generated .vscode/settings.json for {{ host }}"
