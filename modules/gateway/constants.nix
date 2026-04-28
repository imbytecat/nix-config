# 网关核心常量；被 modules/gateway/{tproxy,mihomo}.nix 直接 import（不是 NixOS module options）。
# 改这里，nftables 规则与 mihomo 配置自动一致。
{
  # mihomo TPROXY 监听端口；nftables PREROUTING 把 transit 流量重定向到这里
  tproxyPort = 7894;

  # mihomo HTTP+SOCKS5 混合代理端口；客户端可绕过 TPROXY 直连用
  mixedPort = 7890;

  # mihomo DNS 端口；nftables 把 53 的 TCP/UDP redirect 到这里，避免和 systemd-resolved 抢
  dnsPort = 1053;

  # nftables 给 TPROXY 包打的 fwmark；策略路由按这个值选 routingTable
  routingMark = 6666;

  # 策略路由表号；表里 0.0.0.0/0 → local dev lo，让带 fwmark 的包回到 mihomo socket
  routingTable = 100;
}
