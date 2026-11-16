{
  aspects.homeManager.daily = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      # 不用 Ruby/Python 远程插件；stateVersion < 26.05 会沿用旧默认 true 并告警，显式取新默认。
      withRuby = false;
      withPython3 = false;
    };
  };
}
