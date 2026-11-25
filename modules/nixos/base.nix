{
  aspects.nixos.base =
    { pkgs, inputs, ... }:
    {
      imports = [ inputs.disko.nixosModules.disko ];

      i18n.defaultLocale = "en_US.UTF-8";
      time.timeZone = "Asia/Shanghai";

      # 任一角色落地即用的 CLI 底座；带配置的习惯 workstation 走 HM，server 在 server.nix 放交互回声。
      environment.systemPackages = with pkgs; [
        curl
        git
        lsof
        pciutils
        usbutils
        smartmontools
      ];

      zramSwap.enable = true;
    };
}
