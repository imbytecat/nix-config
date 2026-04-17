default:
    @just --list

[macos]
[group('build')]
rebuild host:
    sudo darwin-rebuild switch --flake .#{{host}}

[linux]
[group('build')]
rebuild host:
    sudo nixos-rebuild switch --flake .#{{host}}

[macos]
[group('build')]
check:
    @nix eval .#darwinConfigurations.mac-mini.system > /dev/null && echo "mac-mini: ok"
    @nix eval .#darwinConfigurations.macbook-air.system > /dev/null && echo "macbook-air: ok"

[linux]
[group('build')]
check:
    @nix eval .#nixosConfigurations.wsl.config.system.build.toplevel > /dev/null && echo "wsl: ok"

[linux]
[group('build')]
rollback:
    sudo nixos-rebuild switch --rollback

[group('nix')]
update:
    nix flake update

[group('nix')]
up input:
    nix flake update {{input}}

[group('nix')]
show:
    nix flake show

[group('nix')]
history:
    nix profile history --profile /nix/var/nix/profiles/system

[group('nix')]
clean:
    nix-collect-garbage -d

[macos]
[group('tools')]
lsp host:
    @jq --arg h "{{host}}" '."nix.serverSettings".nixd.options = {"nix-darwin":{"expr":"(builtins.getFlake (toString ./.)).darwinConfigurations.\($h).options"},"home-manager":{"expr":"(builtins.getFlake (toString ./.)).darwinConfigurations.\($h).options.home-manager.users.type.getSubOptions []"}}' .vscode/settings.base.json > .vscode/settings.json
    @echo "Generated .vscode/settings.json for {{host}}"

[linux]
[group('tools')]
lsp host:
    @jq --arg h "{{host}}" '."nix.serverSettings".nixd.options = {"nixos":{"expr":"(builtins.getFlake (toString ./.)).nixosConfigurations.\($h).options"},"home-manager":{"expr":"(builtins.getFlake (toString ./.)).nixosConfigurations.\($h).options.home-manager.users.type.getSubOptions []"}}' .vscode/settings.base.json > .vscode/settings.json
    @echo "Generated .vscode/settings.json for {{host}}"
