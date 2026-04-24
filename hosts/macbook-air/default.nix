{ ... }:

{
  homebrew.casks = [
    "thaw" # 刘海屏菜单栏管理工具
  ];

  # 显示器常亮，不自动熄屏（nix-darwin 的 power.sleep.* 只作用于 AC）
  power.sleep.display = "never";
  power.sleep.computer = "never";

  system.activationScripts.postActivation.text = ''
    # 电池模式下显示器也永不熄屏
    pmset -b displaysleep 0
    # 电池模式下系统也不因空闲而睡眠（盒盖仍会睡，由 clamshell 独立控制）
    pmset -b sleep 0
    # 禁用电池模式下自动降低亮度（Slightly dim the display on battery）
    pmset -a lessbright 0
    # 禁用显示器睡眠前的半亮度过渡
    pmset -a halfdim 0
  '';

  system.stateVersion = 6;
}
