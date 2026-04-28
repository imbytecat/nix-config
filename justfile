default:
    @just --list

[doc('macOS 本机重建系统')]
[macos]
[group('build')]
rebuild host:
    sudo darwin-rebuild switch --flake .#{{host}}

[doc('NixOS 本机重建系统（远程主机用 deploy）')]
[linux]
[group('build')]
rebuild host:
    sudo nixos-rebuild switch --flake .#{{host}}

[doc('eval 全部 darwinConfigurations，仅检查能否 build')]
[macos]
[group('build')]
check:
    @nix eval .#darwinConfigurations.mac-mini.system > /dev/null && echo "mac-mini: ok"
    @nix eval .#darwinConfigurations.macbook-air.system > /dev/null && echo "macbook-air: ok"

[doc('eval 全部 nixosConfigurations，仅检查能否 build')]
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

# 警告：disko 会按 hosts/<host>/disko.nix 全盘重建，目标机数据全部丢失
# 装完 SSH host key 会变，记得 `ssh-keygen -R <target>`
[doc('远程首次装机：nixos-anywhere kexec → disko 全盘 → install → reboot')]
[group('remote')]
install host target:
    nix run github:nix-community/nixos-anywhere -- \
      --flake ".#{{host}}" \
      --target-host "root@{{target}}" \
      --build-on remote

[doc('远程更新 NixOS 主机（本机构建 → SCP 推送）')]
[linux]
[group('remote')]
deploy host target:
    nixos-rebuild switch \
      --flake ".#{{host}}" \
      --target-host "root@{{target}}" \
      --use-remote-sudo \
      --use-substitutes

# --build-host == --target-host：让目标机自己 build，避开 Mac 跨架构编译 Linux
[doc('远程更新 NixOS 主机（目标机自己 build）')]
[macos]
[group('remote')]
deploy host target:
    nix run nixpkgs#nixos-rebuild -- switch \
      --flake ".#{{host}}" \
      --target-host "root@{{target}}" \
      --build-host "root@{{target}}" \
      --use-remote-sudo \
      --use-substitutes

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

[doc('查看 system profile 历史 generation（仅 NixOS）')]
[group('nix')]
history:
    nix profile history --profile /nix/var/nix/profiles/system

[doc('清理用户级旧 generation 与垃圾')]
[group('nix')]
clean:
    nix-collect-garbage -d

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
