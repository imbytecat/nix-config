{ ... }:

{
  homebrew.casks = [
    "thaw" # 刘海屏菜单栏管理工具
  ];

  # 屏幕/系统常亮，但盒盖仍需能睡
  # 不用 nix-darwin 的 power.sleep.*：它走 systemsetup，会把 SleepDisabled 置 1，
  # 连盒盖（clamshell）睡眠都屏蔽。改用纯 pmset 精确控制。
  system.activationScripts.postActivation.text = ''
    # 空闲永不熄屏、永不系统睡眠（电池 + 插电）
    pmset -a displaysleep 0
    pmset -a sleep 0
    # 清除 SleepDisabled 标记，保留盒盖睡眠（clamshell）
    pmset -a disablesleep 0
    # 禁用电池模式下自动降低亮度
    pmset -a lessbright 0
    # 禁用显示器睡眠前的半亮度过渡
    pmset -a halfdim 0
  '';

  system.stateVersion = 6;
}
