# List all commands
default:
    @just --list

# Rebuild macOS host
[macos]
darwin host:
    sudo darwin-rebuild switch --flake .#{{host}}

# Rebuild WSL host
[linux]
nixos:
    sudo nixos-rebuild switch --flake .#wsl

# Update all flake inputs
update:
    nix flake update

# Edit encrypted secrets
secrets:
    sops secrets/secrets.yaml

# Garbage-collect old generations
gc:
    nix-collect-garbage -d

# Show flake outputs
show:
    nix flake show

# Check configs evaluate without errors (platform-aware, avoids cross-platform IFD)
[macos]
check:
    @nix eval .#darwinConfigurations.mac-mini.system > /dev/null && echo "mac-mini: ok"
    @nix eval .#darwinConfigurations.macbook-air.system > /dev/null && echo "macbook-air: ok"

[linux]
check:
    @nix eval .#nixosConfigurations.wsl.config.system.build.toplevel > /dev/null && echo "wsl: ok"

# Generate .nixd.json for nixd LSP option completion
[macos]
nixd host:
    @echo '{"options":{"nix-darwin":{"expr":"(builtins.getFlake (toString ./.)).darwinConfigurations.{{host}}.options"},"home-manager":{"expr":"(builtins.getFlake (toString ./.)).darwinConfigurations.{{host}}.options.home-manager.users.type.getSubOptions []"}}}' | jq . > .nixd.json
    @echo "Generated .nixd.json for {{host}}"

[linux]
nixd host="wsl":
    @echo '{"options":{"nixos":{"expr":"(builtins.getFlake (toString ./.)).nixosConfigurations.{{host}}.options"},"home-manager":{"expr":"(builtins.getFlake (toString ./.)).nixosConfigurations.{{host}}.options.home-manager.users.type.getSubOptions []"}}}' | jq . > .nixd.json
    @echo "Generated .nixd.json for {{host}}"
