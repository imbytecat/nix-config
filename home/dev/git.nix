{ ... }:

{
  programs.git = {
    enable = true;
    userName = "imbytecat";
    userEmail = "imbytecat@gmail.com";
    signing.format = null;
    settings = {
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
      git.pagers = [
        { pager = "delta --paging=never"; }
      ];
      update.method = "never";
      disableStartupPopups = true;
    };
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      identityFile = "~/.ssh/id_ed25519";
      addKeysToAgent = "yes";
    };
  };
}
