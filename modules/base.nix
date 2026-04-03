{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # ── 核心工具 ──
    curl
    git
    micro
    vim
    wget

    # ── 现代 CLI 替代 ──
    bat # cat
    btop # top
    duf # df
    dust # du
    eza # ls
    fd # find
    jq # JSON
    procs # ps
    ripgrep # grep
    sd # sed
    xh # curl/httpie
    yq # YAML

    # ── 文件管理 ──
    trash-cli
    yazi

    # ── 系统信息 ──
    fastfetch
    tealdeer # tldr
  ];

  # ── Nix 设置 ──
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # 国内镜像（按需取消注释）
    # substituters = [
    #   "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    #   "https://cache.nixos.org"
    # ];
  };

  nixpkgs.config.allowUnfree = true;
}
