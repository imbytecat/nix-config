{ config, lib, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      IdentityFile = "~/.ssh/id_ed25519";
      AddKeysToAgent = "yes";
    };
  };

  # HM 的 store symlink 在仅映射当前 uid 的 user namespace 中显示为 nobody，OpenSSH 会拒绝。
  # 激活时改写为用户所有的 0600 实体文件，并由 Nix 每次覆盖。
  home.file.".ssh/config".enable = false;

  # 等 linkGeneration 清理旧 symlink 后再写实体文件。
  home.activation.sshConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -d -m700 "$HOME/.ssh"
    run install -m600 ${config.home.file.".ssh/config".source} "$HOME/.ssh/config"
  '';
}
