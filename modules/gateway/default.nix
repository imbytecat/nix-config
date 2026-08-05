{
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
    # nftables 由 tproxy.nix 管理。
    firewall.enable = false;
  };

  # 单臂网关；rp_filter 必须按接口关闭，sysctl default 不覆盖现有接口。
  systemd.network.networks."50-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      DHCP = "yes";
      IPv4ReversePathFilter = "no";
    };
    # 忽略 DHCP 明文 DNS，网关自身改用 DoT。
    dhcpV4Config.UseDNS = false;
    linkConfig.RequiredForOnline = "routable";
  };

  # 本机解析不能走 mihomo fake-ip，恢复路径也不能依赖 mihomo。
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "223.5.5.5#dns.alidns.com 120.53.53.53#dot.pub";
      DNSOverTLS = "yes";
      FallbackDNS = "";
      DNSSEC = "no";
      # 必须保留 stub；否则 glibc 绕过 resolved 直连上游。
      DNSStubListener = "yes";
    };
  };
  environment.etc."resolv.conf".source = lib.mkForce "/run/systemd/resolve/stub-resolv.conf";

  # info 日志含浏览域名，仅保留短窗口。
  services.journald.extraConfig = ''
    MaxRetentionSec=3day
    SystemMaxUse=100M
  '';
}
