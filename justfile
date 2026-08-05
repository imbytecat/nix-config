default:
    @just --list


_valid host:
    @bash -euc '[[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "invalid host name: $1" >&2; exit 1; }' _ {{ quote(host) }}

_valid_remote remote:
    @bash -euc '[[ "$1" =~ ^[a-zA-Z0-9_.:-]+$ ]] || { echo "invalid remote: $1" >&2; exit 1; }' _ {{ quote(remote) }}

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
    @nix eval .#nixosConfigurations.ovh-ks-5.config.system.build.toplevel > /dev/null && echo "ovh-ks-5: ok"

[doc('nix flake check —— 格式 + lint + 四台 host 的 eval（在 Linux 上跑才全覆盖：host eval 挂在 x86_64-linux 上，darwin 只跑得到 formatting/lint，用 just eval 补）')]
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
    # 默认 25.11 kexec 会写出目标 6.18 内核无法读取的 mdraid superblock。
    kexec_installer="$(nix build --no-link --print-out-paths .#kexec-installer)"
    hardware_config="./hosts/{{ host }}/hardware-configuration.nix"
    hardware_args=()
    if [ -f "$hardware_config" ]; then
      hardware_args+=(--generate-hardware-config nixos-generate-config "$hardware_config")
    fi
    # nixos-anywhere 会转发目标 host 的 nix.settings 并自动启用 flakes；勿在此复制。
    nix run .#nixos-anywhere -- \
      "${hardware_args[@]}" \
      --kexec "$kexec_installer" \
      --option always-allow-substitutes true \
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

[doc('远程更新（同架构，仅注册下次启动 generation）')]
[linux]
[group('remote')]
deploy-boot host remote: (_valid host) (_valid_remote remote)
    nixos-rebuild boot \
      --flake ".#{{ host }}" \
      --target-host "root@{{ remote }}" \
      --sudo \
      --use-substitutes

# 跨架构让目标机 build，并跳过 macOS 无法执行的 Linux reexec。
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

[doc('查看本机 system profile 的历史 generation')]
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

[doc('格式化整个仓库（treefmt）')]
[group('nix')]
fmt:
    nix fmt

[doc('lint：statix 反模式 + deadnix 死代码')]
[group('check')]
lint:
    statix check
    deadnix --fail --exclude \
      ./hosts/awesome-pc/hardware-configuration.nix \
      ./hosts/ovh-ks-5/hardware-configuration.nix

