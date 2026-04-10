#!/bin/bash
set -euo pipefail

REPO_URL="https://git.furtherverse.com/imbytecat/nix-config.git"
CONFIG_DIR="$HOME/Developer/nix-config"

if [[ -d "$CONFIG_DIR/.git" ]]; then
    git -C "$CONFIG_DIR" pull
else
    mkdir -p "$HOME/Developer"
    git clone "$REPO_URL" "$CONFIG_DIR"
fi

case "$(uname)" in
    Darwin)
        TARGET="${1:?Usage: $0 <mac-mini|macbook-air>}"
        if command -v darwin-rebuild &>/dev/null; then
            sudo darwin-rebuild switch --flake "$CONFIG_DIR#$TARGET"
        else
            sudo nix run nix-darwin -- switch --flake "$CONFIG_DIR#$TARGET"
        fi
        ;;
    Linux)
        sudo nixos-rebuild switch --flake "$CONFIG_DIR#wsl"
        ;;
esac

echo "Done! Restart your shell."
