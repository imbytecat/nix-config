{ username, ... }:

{
  # ── sops (system-level) ─────────────────────────────
  # Use NixOS module instead of home-manager module to avoid
  # systemd user service issues on WSL.
  # Secrets are placed in /run/secrets/<name>.
  sops = {
    age.sshKeyPaths = [ "/home/${username}/.ssh/id_ed25519" ];
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    secrets = {
      ai_gateway_base_url = {
        owner = username;
      };
      ai_gateway_api_key = {
        owner = username;
      };
      exa_api_key = {
        owner = username;
      };
      context7_api_key = {
        owner = username;
      };
    };
  };
}
