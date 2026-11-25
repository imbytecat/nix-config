{
  aspects.nixos.daily =
    { inputs, ... }:
    {
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [ inputs.self.overlays.default ];

      # 界面保持 en_US，时间与日期使用 zh_CN 的 24 小时格式。
      i18n.extraLocaleSettings.LC_TIME = "zh_CN.UTF-8";

      virtualisation.docker.enable = true;
    };
}
