_:

{
  # 令牌走 GH_TOKEN（op-env 从 1Password 注入），所以不需要 keyring 里那份
  # OAuth token，也不需要 hosts.yml —— 新机器 op-env 一刷 gh 就可用，无需交互式登录。
  # 代价：config.yml 变成只读 store 链接，`gh alias set` 之类要改这里而不是命令行。
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      aliases.co = "pr checkout";
    };
  };

  programs.git = {
    enable = true;
    signing.format = null;
    settings = {
      user.name = "imbytecat";
      user.email = "imbytecat@gmail.com";
      merge.conflictstyle = "zdiff3";
      pull.rebase = true;
      push.autoSetupRemote = true;
      init.defaultBranch = "main";
      rerere.enabled = true;
      diff.algorithm = "histogram";
      core.autocrlf = "input";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      line-numbers = true;
    };
  };

  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        nerdFontsVersion = "3";
        showBottomLine = false;
      };
      git.pagers = [ { pager = "delta --paging=never"; } ];
      update.method = "never";
      disableStartupPopups = true;
    };
  };
}
