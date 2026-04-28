{
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./tproxy.nix
    ./mihomo.nix
  ];

  networking = {
    useNetworkd = true;
    useDHCP = false;
    # nftables 规则在 ./tproxy.nix 直接管理
    firewall.enable = false;
  };

  # 单臂网关，所有 ethernet 通吃
  # rp_filter 必须逐接口禁用：sysctl all/default 覆盖不了已存在接口的默认值 2
  systemd.network.networks."50-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      DHCP = "yes";
      IPv4ReversePathFilter = "no";
    };
    dhcpV4Config.UseDNS = true;
    linkConfig.RequiredForOnline = "routable";
  };

  # 禁 stub 监听，让出 53 给 mihomo DNS (1053)
  services.resolved = {
    enable = true;
    settings.Resolve = {
      FallbackDNS = "";
      DNSSEC = "no";
      DNSStubListener = "no";
    };
  };
  environment.etc."resolv.conf".source = lib.mkForce "/run/systemd/resolve/resolv.conf";

  environment.systemPackages = with pkgs; [
    curlMinimal
    yq-go
    mihomo
  ];
}
