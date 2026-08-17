{
  inputs,
  username,
  pkgs,
  config,
  lib,
  system,
  ...
}:

{
  _module.args.aiCatalog = import ./ai-catalog.nix;

  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./shell
    ./dev
  ]
  # imports 阶段用 specialArg system；pkgs 依赖 config 会递归。
  ++ lib.optionals (lib.hasSuffix "-linux" system) [ ./desktop ];

  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
  };

  home = {
    inherit username;
    homeDirectory =
      if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "25.11";
  };

  home.packages = with pkgs; [
    duf
    dust
    jq
    procs
    sd
    socat
    wget
    yq

    gomi
    ouch

    just
    nix-output-monitor
    nvd

    ffmpeg
    pandoc
    libredwg # FreeCAD DWG

    trzsz-ssh
    tsshd
  ];

  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/nix-config";
  };

  programs.fastfetch.enable = true;
  programs.tealdeer = {
    enable = true;
    # Darwin 的 tldr-update launchd 会以 code 5 失败，改用按需更新。
    enableAutoUpdates = false;
    settings.updates.auto_update = true;
  };

  xdg.enable = true;
}
