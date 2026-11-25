let
  cli = {
    programs._1password.enable = true;
  };
in
{
  aspects.nixos.workstation = cli;
  aspects.darwin.workstation = cli;

  aspects.nixos.desktop =
    { username, ... }:
    {
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = [ username ];
      };
    };

  aspects.darwin.desktop.homebrew.casks = [ "1password" ];
}
