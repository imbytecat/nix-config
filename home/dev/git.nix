_:

{
  # 仅用 GH_TOKEN；config.yml 是只读 store 链接，改动需声明在此。
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
