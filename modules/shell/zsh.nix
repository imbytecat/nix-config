let
  enable = {
    programs.zsh.enable = true;
  };
in
{
  aspects.nixos.workstation = enable;
  aspects.darwin.workstation = enable;

  aspects.homeManager.workstation =
    { lib, ... }:
    {
      programs.zsh = {
        enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        # EDITOR=nvim 会让 zsh 默认用 vi 键位。
        defaultKeymap = "emacs";
        # 粘贴的命令里有 # 注释、没加引号的 ? 或 [] 时，照 bash 的行为执行。
        setOptions = [
          "INTERACTIVE_COMMENTS"
          "NO_NOMATCH"
        ];

        shellAliases = {
          # 尾随空格让 sudo 后面的别名也展开。
          sudo = "sudo ";
          ".." = "cd ..";
          "..." = "cd ../..";
          ll = "eza -lh";
          lla = "eza -lah --time-style=long-iso";
          cat = "bat --paging=never";
          lg = "lazygit";
        };

        initContent = lib.mkMerge [
          # 以下全是交互配置。Codex 的 shell 快照会非交互地 source .zshrc，并在每条 agent 命令前 source 快照：
          # 有这行守卫，快照只剩登录环境（实测 209 行，没有则是 7001 行插件函数）；直接 source .zshrc 的工具
          # 也拿不到 zoxide 接管的 cd（目标不存在时会跳去历史目录，`cd 不存在的目录 && rm -rf …` 会删错地方）。
          (lib.mkOrder 0 "[[ -o interactive ]] || return")
          ''
            [[ -f "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"
            # 迁移期间旧 local.zsh 仍可能 export 这个 token，避免 agent 子进程继承。
            unset OP_SERVICE_ACCOUNT_TOKEN
          ''
        ];
      };
    };
}
