default:
    @just --list

# 用法：just rebuild <host>，host 必须是 darwinConfigurations.<host>
[doc('macOS 本机重建系统（在 Mac 本机跑）')]
[macos]
[group('build')]
rebuild host:
    sudo darwin-rebuild switch --flake .#{{host}}

# 用法：just rebuild <host>，例：just rebuild wsl 或 just rebuild mihomo-gateway（在网关本机时）
# 远程主机请用 `just deploy <host> <ip>`，不要走这条
[doc('NixOS 本机重建系统（在 WSL 或服务器本机跑）')]
[linux]
[group('build')]
rebuild host:
    sudo nixos-rebuild switch --flake .#{{host}}

[doc('eval 全部 darwinConfigurations，仅检查能否 build，不真的 build')]
[macos]
[group('build')]
check:
    @nix eval .#darwinConfigurations.mac-mini.system > /dev/null && echo "mac-mini: ok"
    @nix eval .#darwinConfigurations.macbook-air.system > /dev/null && echo "macbook-air: ok"

[doc('eval 全部 nixosConfigurations（WSL + 服务器），仅检查 toplevel 能否 build')]
[linux]
[group('build')]
check:
    @nix eval .#nixosConfigurations.wsl.config.system.build.toplevel > /dev/null && echo "wsl: ok"
    @nix eval .#nixosConfigurations.mihomo-gateway.config.system.build.toplevel > /dev/null && echo "mihomo-gateway: ok"

[doc('回滚到上一个 generation（仅 NixOS 本机）')]
[linux]
[group('build')]
rollback:
    sudo nixos-rebuild switch --rollback

# 用法：just install <host> <target>
# 例：just install mihomo-gateway 192.168.1.123
# 前置：目标机用 NixOS installer 启动并允许 root SSH（可用密码或临时密钥）
# 警告：disko 会按 hosts/<host>/disko.nix 全盘重建，目标机数据全部丢失
# 实现：--build-on remote 让目标机自己构建 closure，本机不需要同架构
# 收尾：装完后 SSH host key 变了，记得 `ssh-keygen -R <target>` 清本地 known_hosts
[doc('远程首次装机：nixos-anywhere kexec → disko 全盘 → install → reboot')]
[group('remote')]
install host target:
    nix run github:nix-community/nixos-anywhere -- \
      --flake ".#{{host}}" \
      --target-host "root@{{target}}" \
      --build-on remote

# 用法：just deploy <host> <target>
# 例：just deploy mihomo-gateway 192.168.1.123
# 实现：本机构建 closure（同架构最快） → SCP 推送 → 目标机切换 generation
# 适用：本机与目标同架构（WSL x86_64 → Linux x86_64 服务器）
[doc('远程更新已部署 NixOS 主机（本机构建 → SCP 推送，同架构最快）')]
[linux]
[group('remote')]
deploy host target:
    nixos-rebuild switch \
      --flake ".#{{host}}" \
      --target-host "root@{{target}}" \
      --use-remote-sudo \
      --use-substitutes

# 用法：just deploy <host> <target>
# 例：just deploy mihomo-gateway 192.168.1.123
# 实现：--build-host == --target-host，让目标机自己 build，避开 Mac 跨架构编译 Linux
# 注：nix-darwin 不带 nixos-rebuild，从 nixpkgs 现取
[doc('远程更新已部署 NixOS 主机（让目标机自己 build，避免 Mac 跨架构）')]
[macos]
[group('remote')]
deploy host target:
    nix run nixpkgs#nixos-rebuild -- switch \
      --flake ".#{{host}}" \
      --target-host "root@{{target}}" \
      --build-host "root@{{target}}" \
      --use-remote-sudo \
      --use-substitutes

[doc('更新所有 flake 输入到 lock 最新')]
[group('nix')]
update:
    nix flake update

# 用法：just up nixpkgs / just up disko / just up home-manager 等
[doc('只更新单个 flake 输入')]
[group('nix')]
up input:
    nix flake update {{input}}

[doc('列出 flake 暴露的所有输出（packages / configurations / overlays...）')]
[group('nix')]
show:
    nix flake show

[doc('看本机 system profile 的历史 generation（仅 NixOS 本机）')]
[group('nix')]
history:
    nix profile history --profile /nix/var/nix/profiles/system

[doc('清理用户级旧 generation 与垃圾，回收空间')]
[group('nix')]
clean:
    nix-collect-garbage -d

# 用法：just lsp <host>，host 用 darwinConfigurations.<host> 名字
[doc('给 VSCode 的 nixd LSP 生成 options expr，让自动补全感知 host 配置（macOS）')]
[macos]
[group('tools')]
lsp host:
    @jq --arg h "{{host}}" '."nix.serverSettings".nixd.options = {"nix-darwin":{"expr":"(builtins.getFlake (toString ./.)).darwinConfigurations.\($h).options"},"home-manager":{"expr":"(builtins.getFlake (toString ./.)).darwinConfigurations.\($h).options.home-manager.users.type.getSubOptions []"}}' .vscode/settings.base.json > .vscode/settings.json
    @echo "Generated .vscode/settings.json for {{host}}"

# 用法：just lsp <host>，host 用 nixosConfigurations.<host> 名字
[doc('给 VSCode 的 nixd LSP 生成 options expr，让自动补全感知 host 配置（Linux）')]
[linux]
[group('tools')]
lsp host:
    @jq --arg h "{{host}}" '."nix.serverSettings".nixd.options = {"nixos":{"expr":"(builtins.getFlake (toString ./.)).nixosConfigurations.\($h).options"},"home-manager":{"expr":"(builtins.getFlake (toString ./.)).nixosConfigurations.\($h).options.home-manager.users.type.getSubOptions []"}}' .vscode/settings.base.json > .vscode/settings.json
    @echo "Generated .vscode/settings.json for {{host}}"
