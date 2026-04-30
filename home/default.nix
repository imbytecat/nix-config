{
  inputs,
  username,
  pkgs,
  config,
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

    gomi
    ouch

    just
    nix-output-monitor
    nvd

    comment-checker
    llm-agents.opencode
    llm-agents.skills

    ffmpeg
    pandoc
    yt-dlp
  ];

  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/nix-config";
  };

  programs.fastfetch.enable = true;
  programs.tealdeer.enable = true;

  xdg.enable = true;
}
