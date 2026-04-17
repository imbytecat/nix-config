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
    dust
    duf
    procs
    sd
    jq
    yq
    wget

    fastfetch
    tealdeer

    gomi
    ouch

    nix-output-monitor
    nvd
    nh
    just

    opencode
    comment-checker
    skills

    ffmpeg
    pandoc
  ];

  xdg.enable = true;
}
