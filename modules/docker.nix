{ config, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    docker-compose
  ];

  # 注：用户 docker 组权限在 hosts/*/default.nix 中配置
  #
  # WSL 环境下如使用 Docker Desktop，可改为：
  #   wsl.docker-desktop.enable = true;
  # 并将上面的 virtualisation.docker.enable 设为 false
}
