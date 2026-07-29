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

  # HM 默认把 ~/.ssh/config symlink 进 store（root:root 444）。任何只映射当前 uid 的
  # user namespace 里（AppImage 的 FHS 包装、systemd 单元的 PrivateTmp、部分 agent 沙盒）
  # uid 0 没有映射，该文件显示成 nobody:nogroup，OpenSSH 的 owner 检查只接受 getuid() 或 0，
  # 于是 "Bad owner or permissions" ——见 home-manager#322。改成激活时落成本用户所有的
  # 真实 600 文件，任何 namespace 里都过检查；每次 switch 覆盖，仍以 Nix 为唯一事实源。
  home.file.".ssh/config".enable = false;

  # 排在 linkGeneration 之后：先让 HM 清掉上一代留下的 ~/.ssh/config symlink（它的 cleanup
  # 只删指向 home-manager-files 的链接，真实文件会被 warn 后跳过），再落我们自己的文件。
  home.activation.sshConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -d -m700 "$HOME/.ssh"
    run install -m600 ${config.home.file.".ssh/config".source} "$HOME/.ssh/config"
  '';
}
