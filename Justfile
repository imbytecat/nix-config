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

# Check flake for errors
check:
    nix flake check --no-build
