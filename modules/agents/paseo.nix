{ inputs, ... }:
let
  port = 6767;
in
{
  # 服务用上游 NixOS 模块（系统服务，以用户身份运行）；macOS 没有现成服务，由桌面端自己起 daemon。
  aspects.nixos.daily =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      hm = config.home-manager.users.${username};
    in
    {
      imports = [ "${inputs.paseo}/nix/module.nix" ];

      services.paseo = {
        enable = true;
        package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.paseo;
        user = username;
        group = "users";
        # 直连只有 Tailscale 加密，防火墙只在 tailscale0 放行；密码用 `paseo daemon set-password` 设。
        listenAddress = "0.0.0.0";
        inherit port;
        relay.enable = false;
        # 上游拼的 PATH 不含 HM sessionPath（mise shims 等），关掉后自己拼。
        inheritUserEnvironment = false;
      };
      # 模块没有密钥文件选项，agent 要的 API key 取自 op-env 的 dotenv。
      systemd.services.paseo.serviceConfig.EnvironmentFile = "${hm.xdg.cacheHome}/op-env/env";
      systemd.services.paseo.environment.PATH = lib.mkForce (
        lib.concatStringsSep ":" (
          map (lib.replaceStrings [ "$HOME" ] [ hm.home.homeDirectory ]) hm.home.sessionPath
          ++ [
            "${hm.home.profileDirectory}/bin"
            "/run/wrappers/bin"
            "/run/current-system/sw/bin"
            "/nix/var/nix/profiles/default/bin"
          ]
        )
      );
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
    };

  # 桌面端复用 ~/.paseo 里已在跑的 daemon（NixOS 上即上面的服务），没有才自己起。
  # llm-agents 只有 Linux 版 paseo-desktop（不自更新）；Mac 只能用会自更新的 cask，CLI 也由 cask 链接。
  aspects.nixos.desktop =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.paseo-desktop
      ];
    };
  aspects.darwin.desktop.homebrew.casks = [ "paseo" ];

  aspects.homeManager.daily =
    {
      aiCatalog,
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # config.json 由 CLI、桌面端与手机 App 改写，只合并声明的键。omp 的模型列表混有网关不提供的内置条目，
      # Paseo 默认挑第一个（claude-fable-5）会一直 503 重试；默认模型与 omp.nix 的 modelRoles.default 一致。
      home.activation.paseoConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (
        lib.hm.generators.mkImpureConfigMerger {
          inherit pkgs;
          format = "json";
          empty = "{}";
          jqOperation = "$dynamic * $static";
          path = "${config.home.homeDirectory}/.paseo/config.json";
          mode = "600";
          staticSettings = (pkgs.formats.json { }).generate "paseo-config.json" {
            version = 1;
            daemon.relay.enabled = false;
            agents.providers.omp = {
              enabled = true;
              additionalModels = [
                {
                  id = aiCatalog.ref "opus";
                  label = aiCatalog.models.opus.name;
                  isDefault = true;
                }
              ];
            };
          };
        }
      );
    };
}
