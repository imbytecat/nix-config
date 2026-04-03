{ config, ... }:

{
  programs.git = {
    enable = true;

    # user.name 和 user.email 需要每人自行设置：
    #   git config --global user.name "你的名字"
    #   git config --global user.email "你的邮箱"

    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
    };

    extraConfig = {
      # 内部 Git 服务器（跳过 SSL 验证）
      http = {
        "https://202.127.0.42:32443" = {
          sslVerify = false;
        };
      };

      credential.helper = "store";
      merge.conflictstyle = "zdiff3";
      pull.rebase = true;
      push.autoSetupRemote = true;
      init.defaultBranch = "main";
      rerere.enabled = true;
    };
  };
}
