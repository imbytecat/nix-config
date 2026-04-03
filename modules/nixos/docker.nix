{ pkgs, username, ... }:

{
  virtualisation.docker.enable = true;

  users.users.${username}.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    docker-compose
  ];

  # WSL 环境下如使用 Docker Desktop，可改为：
  #   wsl.docker-desktop.enable = true;
  # 并将上面的 virtualisation.docker.enable 设为 false
}
