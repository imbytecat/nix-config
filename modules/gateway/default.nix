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
    # 上游 DHCP 下发的 DNS 是明文的，网关自身查询（订阅域名、geo 更新、nix 缓存）
    # 会把这些域名暴露给链路 —— 改用 resolved 自己的 DoT
    dhcpV4Config.UseDNS = false;
    linkConfig.RequiredForOnline = "routable";
  };

  # 网关自身解析：必须走 DoT，且不能走 mihomo（mihomo 返回 fake-ip，本机没有到
  # fake-ip 的路由，会导致订阅拉取失败），也不能依赖 mihomo 存活，保住恢复路径
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "223.5.5.5#dns.alidns.com 120.53.53.53#dot.pub";
      DNSOverTLS = "yes";
      FallbackDNS = "";
      DNSSEC = "no";
      # 必须开 stub：关掉时 resolv.conf 直接写上游 IP，glibc 会绕过 resolved
      # 明文查询；stub 占的是 127.0.0.53:53，与 mihomo 的 1053 不冲突
      DNSStubListener = "yes";
    };
  };
  environment.etc."resolv.conf".source = lib.mkForce "/run/systemd/resolve/stub-resolv.conf";

  # mihomo 的 info 日志逐条记录连接域名，等于一份明文浏览历史。
  # 保留排查能力，但限制落盘窗口。
  services.journald.extraConfig = ''
    MaxRetentionSec=3day
    SystemMaxUse=100M
  '';
}
