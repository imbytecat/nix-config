default:
    @just --list


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


[doc('eval 全部 darwinConfigurations 的 system derivation（跨平台需 remote builder）')]
[macos]
[group('check')]
eval:
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

[doc('对比本机 /run/current-system 与 {{host}} 配置 build 结果（自动 build，hostname 不匹配会拒绝）')]
[group('check')]
diff host: (_guard host) (build host)
    nvd diff /run/current-system result/


# 警告：disko 会按 hosts/<host>/disko.nix 全盘重建，目标机数据全部丢失
# 装完 SSH host key 会变，记得 `ssh-keygen -R <remote>`
[doc('远程首装：nixos-anywhere → disko 全盘 → install → reboot')]
[group('remote')]
install host remote: (_valid host) (_valid_remote remote)
    #!/usr/bin/env bash
    set -euo pipefail
    hardware_config="./hosts/{{ host }}/hardware-configuration.nix"
    hardware_args=()
    if [ -f "$hardware_config" ]; then
      hardware_args+=(--generate-hardware-config nixos-generate-config "$hardware_config")
    fi
    # 不用手写 substituters / 公钥 / experimental-features：nixos-anywhere 默认
    # machineSubstituters=y，会 eval 目标 host 的 nix.settings.{substituters,
    # trusted-public-keys} 写进 installer 的 ~/.config/nix/nix.conf；flake 特性它自己
    # 每条 nix 命令都带 --extra-experimental-features。真源就是 modules/shared/nix.nix
    # 加 hosts/<host> 里的 mkBefore 镜像，别在这里再抄一份。
    nix run .#nixos-anywhere -- \
      "${hardware_args[@]}" \
      --option always-allow-substitutes true \
      --flake ".#{{ host }}" \
      --target-host "root@{{ remote }}" \
      --build-on remote

# 装完机只剩这一步：网关先以 fallback 直连模式跑着，推了 env 才变代理网关。
# 不落盘到仓库、不进 nix store；systemd.paths 监听到 env 变化会自动重新拉订阅。
[doc('把订阅凭据从 1Password 推到网关（hosts/<host>/env.tpl 定义引用）')]
[group('remote')]
gateway-env host remote: (_valid host) (_valid_remote remote)
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    tpl="./hosts/{{ host }}/env.tpl"
    [ -f "$tpl" ] || { echo "no $tpl"; exit 1; }
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    op inject --in-file "$tpl" --out-file "$tmp/env"
    scp -q "$tmp/env" "root@{{ remote }}:/etc/mihomo/env"
    ssh "root@{{ remote }}" chmod 600 /etc/mihomo/env
    echo "pushed; watch: ssh root@{{ remote }} journalctl -fu mihomo-subscribe"

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

