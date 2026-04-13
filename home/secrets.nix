{ config, pkgs, ... }:

{
  sops = {
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
      AI_GATEWAY_BASE_URL:${config.sops.secrets.ai_gateway_base_url.path} \
      AI_GATEWAY_API_KEY:${config.sops.secrets.ai_gateway_api_key.path} \
      EXA_API_KEY:${config.sops.secrets.exa_api_key.path} \
      CONTEXT7_API_KEY:${config.sops.secrets.context7_api_key.path}
      set -l parts (string split : $pair)
      if test -r $parts[2]
        set -gx $parts[1] (cat $parts[2])
      end
    end
  '';
}
