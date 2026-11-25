# 本机平台对应的 flake 输出与重建命令；另一平台的 host 只能 eval 或远程部署。
class := if os() == "macos" { "darwin" } else { "nixos" }
rebuild := if os() == "macos" { "darwin-rebuild" } else { "nixos-rebuild" }

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

# 首次激活前安装 SOPS 解密身份；已有身份或 host 不用 SOPS 时什么也不做。
_sops_key class host remote="":
    scripts/sops-key.sh {{ class }} {{ quote(host) }} {{ quote(remote) }}

[doc('用本机 SSH 私钥编辑工作站密钥，保存后部署到需要更新的主机')]
[group('nix')]
secrets:
    # SOPS 用 200 表示关闭编辑器且内容没有变化。
    nix develop -c sops edit secrets/agents.yaml || { rc=$?; [ "$rc" -eq 200 ] || exit "$rc"; }

[doc('构建 {{host}} 配置（不激活，产 result/）')]
[group('build')]
build host: (_valid host)
    nix build ".#{{ class }}Configurations.{{ host }}.config.system.build.toplevel"

[doc('用 {{host}} 配置激活本机（hostname 不匹配会拒绝）')]
[group('build')]
switch host: (_guard host) (_sops_key class host)
    sudo {{ rebuild }} switch --flake .#{{ host }}

[doc('用 {{host}} 配置注册下次启动 generation，不激活（hostname 不匹配会拒绝）')]
[group('build')]
[linux]
boot host: (_guard host) (_sops_key class host)
    sudo nixos-rebuild boot --flake .#{{ host }}

[doc('回滚到上一个 generation（NixOS 本机）')]
[group('build')]
[linux]
rollback:
    sudo nixos-rebuild switch --rollback

[doc('打印每台 host 的 toplevel drvPath；纯重构前后应逐行相同。macOS 只含 darwin：NixOS 桌面求值依赖 IFD')]
[group('check')]
eval:
    #!/usr/bin/env bash
    set -euo pipefail
    for configs in {{ if os() == "linux" { "nixosConfigurations darwinConfigurations" } else { "darwinConfigurations" } }}; do
      nix eval --raw ".#$configs" --apply 'cs: builtins.concatStringsSep "" (map (n: "${n} ${cs.${n}.config.system.build.toplevel.drvPath}\n") (builtins.attrNames cs))'
    done

[doc('nix flake check：格式、lint、全部 host 的 eval。host eval 挂在 x86_64-linux 上，macOS 用 just eval 补')]
[group('check')]
check:
    nix flake check --show-trace

[doc('dry-run 看 {{host}} 配置会编译/下载什么（含 home-manager closure，仅本平台 host）')]
[group('check')]
dry host: (_valid host)
    @nix build --dry-run ".#{{ class }}Configurations.{{ host }}.config.system.build.toplevel" 2>&1 \
      | sed -E 's|/nix/store/[a-z0-9]{32}-||g'

[doc('对比本机 /run/current-system 与 {{host}} 配置 build 结果（自动 build，hostname 不匹配会拒绝）')]
[group('check')]
diff host: (_guard host) (build host)
    nvd diff /run/current-system result/

[doc('lint：actionlint 工作流 + statix 反模式 + deadnix 死代码')]
[group('check')]
lint:
    actionlint .github/workflows/*.yml
    statix check
    deadnix --fail --exclude \
      ./hosts/awesome-devbox/hardware-configuration.nix \
      ./hosts/awesome-pc/hardware-configuration.nix \
      ./hosts/ovh-ks-5/hardware-configuration.nix

# 警告：disko 会按该 host 的磁盘布局（single-disk / grub-raid adapter 加 hosts/<host> 的设备）全盘重建，目标机数据全部丢失
# 装完 SSH host key 会变，记得 `ssh-keygen -R <remote>`
[doc('远程首装：引导 kexec → 自建同内核 kexec → disko 全盘 → install → reboot')]
[group('remote')]
install host remote: (_valid host) (_valid_remote remote)
    scripts/install.sh {{ quote(host) }} {{ quote(remote) }}

[doc('远程更新 NixOS host 并激活')]
[group('remote')]
deploy host remote: (_rebuild "switch" host remote)

[doc('远程更新 NixOS host，仅注册下次启动 generation')]
[group('remote')]
deploy-boot host remote: (_rebuild "boot" host remote)

# 同架构：本机构建后推送。
[linux]
_rebuild action host remote: (_valid host) (_valid_remote remote) (_sops_key "nixos" host remote)
    nixos-rebuild {{ action }} \
      --flake ".#{{ host }}" \
      --target-host "root@{{ remote }}" \
      --sudo \
      --use-substitutes

# 跨架构让目标机 build，并跳过 macOS 无法执行的 Linux reexec。
[macos]
_rebuild action host remote: (_valid host) (_valid_remote remote) (_sops_key "nixos" host remote)
    nix run nixpkgs#nixos-rebuild -- {{ action }} \
      --flake ".#{{ host }}" \
      --target-host "root@{{ remote }}" \
      --build-host "root@{{ remote }}" \
      --sudo \
      --use-substitutes \
      --no-reexec

[doc('更新 flake 输入（brew-src 先跟到 Homebrew/brew 最新 release）')]
[group('nix')]
update:
    #!/usr/bin/env bash
    set -euo pipefail
    # sed 读完整个输出，不像 head 提前关管道让 git 吃 SIGPIPE。
    tag="$(git ls-remote --tags --refs --sort=-version:refname https://github.com/Homebrew/brew '[0-9]*' | sed -n '1s|.*refs/tags/||p')"
    : "${tag:?no Homebrew/brew release tag}"
    sed -i.bak -E "s|github:Homebrew/brew/[0-9.]+|github:Homebrew/brew/${tag}|" flake.nix
    rm flake.nix.bak
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
