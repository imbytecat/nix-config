{
  aspects.nixos.daily =
    {
      pkgs,
      username,
      sshKeys,
      ...
    }:
    {
      users.users.${username} = {
        isNormalUser = true;
        shell = pkgs.zsh;
        extraGroups = [
          "wheel"
          "docker"
        ];
        openssh.authorizedKeys.keys = sshKeys;
      };

      security.sudo.wheelNeedsPassword = false;
    };

  # nix-darwin 的 homebrew 与用户级 defaults 都依赖 primaryUser，账户因此属于 Darwin base。
  aspects.darwin.base =
    {
      pkgs,
      username,
      sshKeys,
      ...
    }:
    {
      system.primaryUser = username;

      users.knownUsers = [ username ];
      users.users.${username} = {
        home = "/Users/${username}";
        shell = pkgs.zsh;
        uid = 501;
        openssh.authorizedKeys.keys = sshKeys;
      };

      security.sudo.extraConfig = ''
        ${username} ALL=(ALL) NOPASSWD:ALL
      '';

      security.pam.services.sudo_local.touchIdAuth = true;
    };
}
