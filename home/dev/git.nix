{ ... }:

{
  programs.git = {
    enable = true;

    # user.name / user.email: set per-user via git config or ~/.zshrc.local
    #   git config --global user.name "Your Name"
    #   git config --global user.email "your@email.com"

    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        hyperlinks = true;
      };
    };

    extraConfig = {
      # Internal Git server (skip SSL verification)
      http."https://202.127.0.42:32443".sslVerify = false;

      credential.helper = "store";
      merge.conflictstyle = "zdiff3";
      pull.rebase = true;
      push.autoSetupRemote = true;
      init.defaultBranch = "main";
      rerere.enabled = true;
      diff.algorithm = "histogram";
      core.autocrlf = "input";
    };
  };

  # ── Lazygit ──────────────────────────────────────────
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        nerdFontsVersion = "3";
        showBottomLine = false;
      };
      git.paging = {
        pager = "delta --paging=never";
      };
      update.method = "never";
      disableStartupPopups = true;
    };
  };

  # ── GitHub CLI ───────────────────────────────────────
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
  };
}
