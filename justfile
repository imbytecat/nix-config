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


# 只在首次激活时安装同一 SSH 身份派生的解密密钥，SSH 登录私钥留在调用端。
_agent_key host remote="":
    #!/usr/bin/env bash
    set -euo pipefail
    case {{ quote(host) }} in awesome-macbook-air|awesome-pc|agent-server) ;; *) exit 0 ;; esac
    remote={{ quote(remote) }}
    if [[ -n "$remote" ]]; then
      run=(ssh -T -o StrictHostKeyChecking=ask "root@$remote")
    else
      run=(sudo)
    fi
    actual=$("${run[@]}" hostname -s)
    [[ "$actual" == {{ quote(host) }} ]] || { echo "refuse: hostname=$actual != {{host}}" >&2; exit 1; }
    key=/var/lib/sops-nix/agents-key.txt
    if "${run[@]}" test -s "$key"; then exit 0; fi
    # 在发送任何秘密前检查调用端的私钥与密文匹配。
    identity=$(nix develop -c bash -ec 'sops decrypt secrets/agents.yaml >/dev/null; exec "$SOPS_AGE_KEY_CMD"')
    install_key='set -eu
      umask 077
      dir=/var/lib/sops-nix
      mkdir -p "$dir"
      tmp=$(mktemp "$dir/.agents-key.XXXXXX")
      trap "rm -f -- $tmp" EXIT
      IFS= read -r identity
      case "$identity" in AGE-SECRET-KEY-1*) ;; *) exit 1 ;; esac
      echo "$identity" > "$tmp"
      ln "$tmp" "$dir/agents-key.txt" || cmp -s "$tmp" "$dir/agents-key.txt"'
    if [[ -n "$remote" ]]; then
      printf '%s\n' "$identity" | ssh -T -o StrictHostKeyChecking=yes "root@$remote" "$install_key"
    else
      printf '%s\n' "$identity" | sudo sh -c "$install_key"
    fi

[doc('用本机 SSH 私钥编辑 agent 密钥，保存后部署到需要更新的主机')]
[group('nix')]
secrets:
    # SOPS 用 200 表示关闭编辑器且内容没有变化。
    nix develop -c sops edit secrets/agents.yaml || { rc=$?; [ "$rc" -eq 200 ] || exit "$rc"; }


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
switch host: (_guard host) (_agent_key host)
    sudo darwin-rebuild switch --flake .#{{ host }}

[doc('用 {{host}} 配置激活本机（hostname 不匹配会拒绝）')]
[linux]
[group('build')]
switch host: (_guard host) (_agent_key host)
    sudo nixos-rebuild switch --flake .#{{ host }}

[doc('用 {{host}} 配置注册下次启动 generation，不激活（hostname 不匹配会拒绝）')]
[linux]
[group('build')]
boot host: (_guard host) (_agent_key host)
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
    @nix eval .#nixosConfigurations.agent-server.config.system.build.toplevel > /dev/null && echo "agent-server: ok"
    @nix eval .#nixosConfigurations.awesome-pc.config.system.build.toplevel > /dev/null && echo "awesome-pc: ok"
    @nix eval .#nixosConfigurations.homelab-server.config.system.build.toplevel > /dev/null && echo "homelab-server: ok"
    @nix eval .#nixosConfigurations.mihomo-gateway.config.system.build.toplevel > /dev/null && echo "mihomo-gateway: ok"
    @nix eval .#nixosConfigurations.ovh-ks-5.config.system.build.toplevel > /dev/null && echo "ovh-ks-5: ok"

[doc('nix flake check —— 格式 + lint + 六台 host 的 eval（在 Linux 上跑才全覆盖：host eval 挂在 x86_64-linux 上，darwin 只跑得到 formatting/lint，用 just eval 补）')]
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
[doc('远程首装：引导 kexec → 自建同内核 kexec → disko 全盘 → install → reboot')]
[group('remote')]
install host remote: (_valid host) (_valid_remote remote)
    #!/usr/bin/env bash
    set -euo pipefail
    target="root@{{ remote }}"
    ssh_opts=(-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR)
    export NIX_SSHOPTS="${ssh_opts[*]}"
    hardware_config="./hosts/{{ host }}/hardware-configuration.nix"
    hardware_args=()
    # 只对 git tracked 的 hardware config 请求重新生成；未跟踪文件不会进入目标 build。
    if git ls-files --error-unmatch "$hardware_config" > /dev/null 2>&1; then
      hardware_args+=(--generate-hardware-config nixos-generate-config "$hardware_config")
    fi
    # 两次 kexec 之间用本机密钥登录；kexec 环境继承上一环境 root 的 authorized_keys。
    ssh-copy-id "${ssh_opts[@]}" "$target"
    # 第一次只为在目标机上拿到 Nix；上游镜像内核比目标新，不能让它建 md 阵列（见 packages.nix）。
    nix run .#nixos-anywhere -- \
      --phases kexec \
      --kexec "$(nix build --no-link --print-out-paths .#kexec-bootstrap)" \
      --flake ".#{{ host }}" \
      --target-host "$target"
    kexec="$(nix build --no-link --print-out-paths --eval-store auto --store "ssh-ng://$target" .#packages.x86_64-linux.kexec-installer)"
    ssh "${ssh_opts[@]}" "$target" "mkdir -p /root/kexec && tar -xzf $kexec/*.tar.gz -C /root/kexec && TMPDIR=/root/kexec setsid --wait /root/kexec/kexec/run"
    # 新环境是全新 initrd，没有 /root/kexec；看到它消失才算切换完成。
    for _ in $(seq 60); do
      sleep 5
      ssh "${ssh_opts[@]}" "$target" 'test ! -e /root/kexec' && break
    done
    got="$(ssh "${ssh_opts[@]}" "$target" uname -r)"
    want="$(nix eval --raw ".#nixosConfigurations.{{ host }}.config.boot.kernelPackages.kernel.modDirVersion")"
    if [[ "$(printf '%s\n' "$got" "$want" | sort -V | tail -1)" != "$want" ]]; then
      echo "安装环境内核 $got 比目标 $want 新，建出的 md 阵列目标组装不了" >&2
      exit 1
    fi
    # nixos-anywhere 会转发目标 host 的 nix.settings 并自动启用 flakes；勿在此复制。
    nix run .#nixos-anywhere -- \
      "${hardware_args[@]}" \
      --phases disko,install,reboot \
      --option always-allow-substitutes true \
      --flake ".#{{ host }}" \
      --target-host "$target" \
      --build-on remote

[doc('远程更新（同架构，本机构建后 SCP 推送）')]
[linux]
[group('remote')]
deploy host remote: (_valid host) (_valid_remote remote) (_agent_key host remote)
    nixos-rebuild switch \
      --flake ".#{{ host }}" \
      --target-host "root@{{ remote }}" \
      --sudo \
      --use-substitutes

[doc('远程更新（同架构，仅注册下次启动 generation）')]
[linux]
[group('remote')]
deploy-boot host remote: (_valid host) (_valid_remote remote) (_agent_key host remote)
    nixos-rebuild boot \
      --flake ".#{{ host }}" \
      --target-host "root@{{ remote }}" \
      --sudo \
      --use-substitutes

# 跨架构让目标机 build，并跳过 macOS 无法执行的 Linux reexec。
[doc('远程更新（跨架构，目标机自己 build）')]
[macos]
[group('remote')]
deploy host remote: (_valid host) (_valid_remote remote) (_agent_key host remote)
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
deploy-boot host remote: (_valid host) (_valid_remote remote) (_agent_key host remote)
    nix run nixpkgs#nixos-rebuild -- boot \
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

[doc('lint：actionlint 工作流 + statix 反模式 + deadnix 死代码')]
[group('check')]
lint:
    actionlint .github/workflows/*.yml
    statix check
    deadnix --fail --exclude \
      ./hosts/agent-server/hardware-configuration.nix \
      ./hosts/awesome-pc/hardware-configuration.nix \
      ./hosts/ovh-ks-5/hardware-configuration.nix

