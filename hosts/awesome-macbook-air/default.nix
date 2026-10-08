{ pkgs, ... }:

{
  homebrew.casks = [
    "thaw" # 刘海菜单栏
  ];

  # 淘宝复制品（RDV2/Easy 类）用 PM3GENERIC；默认 PM3RDV4 固件刷到这类板子上会不正常
  environment.systemPackages = [ (pkgs.proxmark3.override { withGeneric = true; }) ];

  # 不用 power.sleep.*：systemsetup -setComputerSleep Never 会屏蔽合盖睡眠
  system.activationScripts.postActivation.text = ''
    pmset -a displaysleep 0
    pmset -a sleep 0
    pmset -a disablesleep 0
    pmset -a lessbright 0
    pmset -a halfdim 0
  '';

  system.stateVersion = 6;
}
