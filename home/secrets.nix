{
  config,
  pkgs,
  lib,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;

  # On Darwin, sops secrets are managed by the home-manager module;
  # on NixOS, they are managed by the system module → /run/secrets/<name>.
  secretPath = name: if isDarwin then config.sops.secrets.${name}.path else "/run/secrets/${name}";
in
{
  # sops home-manager config — Darwin only
  # NixOS uses the system-level module (modules/nixos/secrets.nix)
  # to avoid systemd user service issues on WSL.
  sops = lib.mkIf isDarwin {
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    secrets = {
      ai_gateway_base_url = { };
      ai_gateway_api_key = { };
      exa_api_key = { };
      context7_api_key = { };
    };
  };

  # Generate age key from ed25519 SSH key for sops CLI
  home.activation.sopsAgeKey = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    KEY_DIR="${config.home.homeDirectory}/.config/sops/age"
    KEY_FILE="$KEY_DIR/keys.txt"
    SSH_KEY="${config.home.homeDirectory}/.ssh/id_ed25519"
    if [ -f "$SSH_KEY" ] && [ ! -f "$KEY_FILE" ]; then
      mkdir -p "$KEY_DIR"
      ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "$SSH_KEY" > "$KEY_FILE"
      chmod 600 "$KEY_FILE"
    fi
  '';

  programs.fish.interactiveShellInit = ''
    # sops-nix secrets → env vars
    for pair in \
      AI_GATEWAY_BASE_URL:${secretPath "ai_gateway_base_url"} \
      AI_GATEWAY_API_KEY:${secretPath "ai_gateway_api_key"} \
      EXA_API_KEY:${secretPath "exa_api_key"} \
      CONTEXT7_API_KEY:${secretPath "context7_api_key"}
      set -l parts (string split : $pair)
      if test -r $parts[2]
        set -gx $parts[1] (cat $parts[2])
      end
    end
  '';
}
