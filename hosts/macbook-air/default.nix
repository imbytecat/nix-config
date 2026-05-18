{ ... }:

{
  imports = [ ../../modules/darwin/daily.nix ];

  homebrew.casks = [
    "thaw" # 刘海屏菜单栏管理
  ];

  # 用纯 pmset 而不是 power.sleep.*：后者走 systemsetup 会把 SleepDisabled 置 1
  # 连合盖睡眠都屏蔽，笔记本不能要。
  system.activationScripts.postActivation.text = ''
    pmset -a displaysleep 0
    pmset -a sleep 0
    pmset -a disablesleep 0
    pmset -a lessbright 0
    pmset -a halfdim 0
  '';

  system.stateVersion = 6;
}
