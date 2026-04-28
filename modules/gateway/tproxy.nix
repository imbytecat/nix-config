{ ... }:

let
  constants = import ./constants.nix;
  inherit (constants)
    tproxyPort
    dnsPort
    routingMark
    routingTable
    ;
in
{
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;

    # rp_filter 取 max(all, interface)；逐接口禁用见 networkd 配置
    "net.ipv4.conf.all.rp_filter" = 0;
    "net.ipv4.conf.default.rp_filter" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    # 阻断 IPv6 转发，防绕过代理
    "net.ipv6.conf.all.forwarding" = 0;
    "net.ipv6.conf.default.forwarding" = 0;

    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  networking.nftables = {
    enable = true;
    ruleset = ''
      table ip mihomo {
        chain prerouting {
          type filter hook prerouting priority mangle; policy accept;

          meta mark ${toString routingMark} return
          ip daddr { 127.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } return
          fib daddr type { local, broadcast, multicast } return
          meta l4proto { tcp, udp } tproxy ip to 127.0.0.1:${toString tproxyPort} meta mark set ${toString routingMark} accept
        }
      }

      table inet mihomo-dns {
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;
          meta l4proto { tcp, udp } th dport 53 redirect to :${toString dnsPort}
        }
      }

      table ip6 mihomo {
        chain forward {
          type filter hook forward priority filter; policy drop;
        }
      }
    '';
  };

  networking.iproute2.enable = true;

  systemd.network.networks."99-tproxy" = {
    matchConfig.Name = "lo";
    networkConfig.IPv4ReversePathFilter = "no";
    routingPolicyRules = [
      {
        FirewallMark = routingMark;
        Table = routingTable;
        Priority = 100;
      }
    ];
    routes = [
      {
        # 把打了 fwmark 的包投递回本机，由 mihomo TPROXY socket 接管
        Destination = "0.0.0.0/0";
        Type = "local";
        Table = routingTable;
      }
    ];
  };
}
