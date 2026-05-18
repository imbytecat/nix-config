{ ... }:

{
  imports = [ ../../modules/darwin/daily.nix ];

  homebrew.casks = [
    "thaw"
  ];

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
