{ lib, ... }:

{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
    # 国内镜像（按需取消注释）
    # substituters = [
    #   "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    #   "https://cache.nixos.org"
    # ];
  };

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ (import ../../overlays) ];
  };
}
