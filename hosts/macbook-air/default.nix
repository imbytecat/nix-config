{ ... }:

{
  homebrew.casks = [
    "thaw" # 刘海屏菜单栏管理
  ];

  # 不用 nix-darwin 的 power.sleep.*：它走 systemsetup 会把 SleepDisabled 置 1，
  # 连盒盖（clamshell）睡眠都屏蔽。改用纯 pmset：屏幕/系统常亮，盒盖仍能睡。
  system.activationScripts.postActivation.text = ''
    pmset -a displaysleep 0
    pmset -a sleep 0
    pmset -a disablesleep 0
    pmset -a lessbright 0
    pmset -a halfdim 0
  '';

  system.stateVersion = 6;
}
