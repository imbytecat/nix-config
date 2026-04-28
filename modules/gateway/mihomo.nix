{
  pkgs,
  lib,
  ...
}:

let
  constants = import ./constants.nix;
  inherit (constants) tproxyPort mixedPort dnsPort;

  stateDir = "/var/lib/mihomo";
  configFile = "${stateDir}/config.yaml";
  envFile = "/etc/mihomo/env";

  baseConfig = {
    allow-lan = true;
    external-controller = "0.0.0.0:9090";
    tproxy-port = tproxyPort;
    mixed-port = mixedPort;
    find-process-mode = "off";
    ipv6 = false;
    profile.store-fake-ip = true;
    dns = {
      enable = true;
      listen = "0.0.0.0:${toString dnsPort}";
      ipv6 = false;
    };
  };

  fallbackConfig = (removeAttrs baseConfig [ "external-controller" ]) // {
    mode = "direct";
    log-level = "info";
    dns = baseConfig.dns // {
      enhanced-mode = "redir-host";
      default-nameserver = [
        "114.114.114.114"
        "223.5.5.5"
        "119.29.29.29"
      ];
      nameserver = [
        "https://dns.alidns.com/dns-query"
        "https://doh.pub/dns-query"
      ];
    };
  };

  yamlFormat = pkgs.formats.yaml { };
  baseConfigYaml = yamlFormat.generate "base-config.yaml" baseConfig;
  fallbackConfigYaml = yamlFormat.generate "fallback.yaml" fallbackConfig;

  subscribeScript = pkgs.writeShellScript "mihomo-subscribe" ''
    set -euo pipefail

    if [ -z "''${CONFIG_URL:-}" ]; then
      echo "CONFIG_URL not set in ${envFile}"
      exit 0
    fi

    if [ -z "''${SECRET:-}" ]; then
      echo "SECRET not set in ${envFile}; required for external-controller API authentication"
      exit 1
    fi

    tmp="$(mktemp -p "${stateDir}" .mihomo-config.XXXXXX.yaml)"

    cleanup() {
      rm -f "$tmp"
    }
    trap cleanup EXIT

    echo "Fetching subscription..."
    curl -fsSL --connect-timeout 30 --max-time 120 \
      --retry 3 --retry-delay 2 --retry-all-errors \
      -o "$tmp" "$CONFIG_URL"

    echo "Sanitizing subscription..."
    yq -i '
      del(.routing-mark) |
      del(.tun) |
      del(.listeners) |
      del(.port) |
      del(.socks-port) |
      del(.redir-port) |
      del(.mixed-port) |
      del(.tproxy-port) |
      del(.allow-lan) |
      del(.bind-address) |
      del(.external-controller) |
      del(.secret)
    ' "$tmp"

    yq -i '. * load("${baseConfigYaml}")' "$tmp"

    SECRET="$SECRET" yq -i '.secret = strenv(SECRET)' "$tmp"

    echo "Validating configuration..."
    if ! output=$(mihomo -t -f "$tmp" -d "${stateDir}" 2>&1); then
      echo "Validation failed:"
      echo "$output"
      exit 1
    fi
    echo "$output"

    if [ -f "${configFile}" ] && [ "$(sha256sum < "$tmp")" = "$(sha256sum < "${configFile}")" ]; then
      echo "No changes; skip restart"
      exit 0
    fi

    if [ -f "${configFile}" ]; then
      cp -f "${configFile}" "${configFile}.bak"
    fi
    mv -f "$tmp" "${configFile}"

    echo "Configuration updated; restarting mihomo"
    systemctl restart mihomo
  '';
in
{
  services.mihomo = {
    enable = true;
    configFile = configFile;
  };

  systemd.tmpfiles.rules = [
    "d /etc/mihomo 0750 root root -"
    "C ${configFile} - - - - ${fallbackConfigYaml}"
  ];

  systemd.services.mihomo-subscribe = {
    description = "Fetch and validate Mihomo subscription";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "mihomo.service"
    ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = envFile;
    path = with pkgs; [
      curlMinimal
      yq-go
      mihomo
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = subscribeScript;
      EnvironmentFile = [ "-${envFile}" ];
      ReadWritePaths = [ stateDir ];
    };
  };

  systemd.timers.mihomo-subscribe = {
    description = "Periodic Mihomo subscription update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnUnitActiveSec = "6h";
      Persistent = true;
    };
  };

  systemd.paths.mihomo-subscribe = {
    description = "Trigger subscription fetch when env file changes";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = envFile;
      Unit = "mihomo-subscribe.service";
    };
  };

  systemd.services.mihomo = {
    after = [
      "network.target"
      "nftables.service"
    ];
    wants = [ "nftables.service" ];
    requires = [ "nftables.service" ];

    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";

      AmbientCapabilities = lib.mkForce [ "CAP_NET_ADMIN" ];
      CapabilityBoundingSet = lib.mkForce [ "CAP_NET_ADMIN" ];
      PrivateUsers = lib.mkForce false;

      # 上游默认只允许 AF_INET{,6}；Go net/route.FetchRIB (UDP DIRECT dialer) 需要
      # AF_NETLINK 枚举路由，否则所有 UDP DIRECT 静默失败。TCP DIRECT 不受影响。
      RestrictAddressFamilies = lib.mkForce [
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];

      LimitNOFILE = 1000000;
      StateDirectory = "mihomo";
    };
  };
}
