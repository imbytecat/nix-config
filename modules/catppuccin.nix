let
  # 显式 autoEnable 兼容 upstream 26.11 语义，确保 ports 真正启用。
  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
  };
in
{
  aspects.nixos.desktop =
    { inputs, ... }:
    {
      imports = [ inputs.catppuccin.nixosModules.catppuccin ];
      inherit catppuccin;
    };

  aspects.homeManager.workstation =
    { inputs, ... }:
    {
      imports = [ inputs.catppuccin.homeModules.catppuccin ];
      inherit catppuccin;
    };
}
