# 直接 import 的纯 attrs（不是 NixOS module options），改这里 tproxy 与 mihomo 配置自动一致
{
  tproxyPort = 7894;
  mixedPort = 7890;
  dnsPort = 1053;
  # nftables 给 TPROXY 包打的 fwmark；策略路由按它选 routingTable
  routingMark = 6666;
  # 策略路由表：0.0.0.0/0 → local dev lo，让带 fwmark 的包回到 mihomo socket
  routingTable = 100;
}
