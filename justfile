# List all commands
default:
    @just --list

############################################################################
#
#  System rebuild
#
############################################################################

# Rebuild and switch to new system configuration
[macos]
[group('build')]
rebuild host:
    sudo darwin-rebuild switch --flake .#{{host}}

# Rebuild and switch to new system configuration
[linux]
[group('build')]
rebuild host:
    sudo nixos-rebuild switch --flake .#{{host}}

# Check configs evaluate without errors
[macos]
[group('build')]
check:
    @nix eval .#darwinConfigurations.mac-mini.system > /dev/null && echo "mac-mini: ok"
    @nix eval .#darwinConfigurations.macbook-air.system > /dev/null && echo "macbook-air: ok"

# Rollback to previous system generation
[linux]
[group('build')]
rollback:
    sudo nixos-rebuild switch --rollback

# Check configs evaluate without errors
[linux]
[group('build')]
check:
    @nix eval .#nixosConfigurations.wsl.config.system.build.toplevel > /dev/null && echo "wsl: ok"

############################################################################
#
#  Nix maintenance
#
############################################################################

# Update all flake inputs
[group('nix')]
update:
    nix flake update

# Update a single flake input (e.g. just up nixpkgs)
[group('nix')]
up input:
    nix flake update {{input}}

# Show flake outputs
[group('nix')]
show:
    nix flake show

# List all generations of the system profile
[group('nix')]
history:
    nix profile history --profile /nix/var/nix/profiles/system

# Remove old generations and garbage-collect the Nix store
[group('nix')]
clean:
    nix-collect-garbage -d

############################################################################
#
#  Cachix
#
############################################################################

# Rebuild, push to Cachix, and switch (requires CACHIX_AUTH_TOKEN from op-env)
[macos]
[group('cachix')]
rebuild-push host:
    nix run nixpkgs#cachix -- watch-exec imbytecat -- sudo darwin-rebuild switch --flake .#{{host}}

# Rebuild, push to Cachix, and switch (requires CACHIX_AUTH_TOKEN from op-env)
[linux]
[group('cachix')]
rebuild-push host:
    nix run nixpkgs#cachix -- watch-exec imbytecat -- sudo nixos-rebuild switch --flake .#{{host}}

############################################################################
#
#  Tooling
#
############################################################################

# Generate .vscode/settings.json with LSP option completion
[macos]
[group('tools')]
lsp host:
    @jq --arg h "{{host}}" '."nix.serverSettings".nixd.options = {"nix-darwin":{"expr":"(builtins.getFlake (toString ./.)).darwinConfigurations.\($h).options"},"home-manager":{"expr":"(builtins.getFlake (toString ./.)).darwinConfigurations.\($h).options.home-manager.users.type.getSubOptions []"}}' .vscode/settings.base.json > .vscode/settings.json
    @echo "Generated .vscode/settings.json for {{host}}"

# Generate .vscode/settings.json with LSP option completion
[linux]
[group('tools')]
lsp host:
    @jq --arg h "{{host}}" '."nix.serverSettings".nixd.options = {"nixos":{"expr":"(builtins.getFlake (toString ./.)).nixosConfigurations.\($h).options"},"home-manager":{"expr":"(builtins.getFlake (toString ./.)).nixosConfigurations.\($h).options.home-manager.users.type.getSubOptions []"}}' .vscode/settings.base.json > .vscode/settings.json
    @echo "Generated .vscode/settings.json for {{host}}"
