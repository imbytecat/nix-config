{
  inputs,
  username,
  pkgs,
  ...
}:

{
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./shell
    ./dev
  ];

  catppuccin = {
    enable = true;
    flavor = "mocha";
  };

  home = {
    username = username;
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "25.11";
  };

  home.packages = with pkgs; [
    duf
    dust
    jq
    procs
    sd
    wget
    yq

    fastfetch
    tealdeer

    gomi
    ouch

    just
    nh
    nix-output-monitor
    nvd

    comment-checker
    opencode
    skills

    ffmpeg
    pandoc
  ];

  xdg.enable = true;
}
