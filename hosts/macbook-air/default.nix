{ ... }:

{
  homebrew.casks = [
    "thaw" # 刘海屏菜单栏管理工具
  ];

  # 外接显示器场景 — 显示器常亮，不自动熄屏
  power.sleep.display = "never";

  system.activationScripts.postActivation.text = ''
    # 禁用电池模式下自动降低亮度（Slightly dim the display on battery）
    pmset -a lessbright 0
    # 禁用显示器睡眠前的半亮度过渡
    pmset -a halfdim 0
  '';

  system.stateVersion = 6;
}
