#!/bin/bash
set -euo pipefail

REPO_URL="https://git.furtherverse.com/imbytecat/nix-config.git"
CONFIG_DIR="$HOME/.config/nix-config"

if [[ -d "$CONFIG_DIR/.git" ]]; then
    git -C "$CONFIG_DIR" pull
else
    git clone "$REPO_URL" "$CONFIG_DIR"
fi

case "$(uname)" in
    Darwin)
        TARGET="${1:?Usage: $0 <mac-mini|macbook-air>}"
        darwin-rebuild switch --flake "$CONFIG_DIR#$TARGET"
        ;;
    Linux)
        sudo nixos-rebuild switch --flake "$CONFIG_DIR#wsl"
        ;;
esac

echo "Done! Restart your shell."
