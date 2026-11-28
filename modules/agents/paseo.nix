{ inputs, ... }:
let
  # 0.17.3 没有 daemon 级默认模式配置。补丁改已打包的 JS，保留上游二进制缓存。
  paseoFor =
    pkgs:
    pkgs.applyPatches {
      src = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.paseo;
      patches = [ ./_paseo-default-modes.patch ];
      postPatch = ''
        substituteInPlace bin/paseo bin/paseo-server --replace-fail "$src/libexec/paseo" "$out/libexec/paseo"
        ${pkgs.nodejs_22}/bin/node ${./_paseo-default-modes.test.mjs} "$PWD/libexec/paseo"
      '';
    };

  mergeSettings =
    lib: pkgs: path: name: settings:
    lib.hm.dag.entryAfter [ "linkGeneration" ] (
      lib.hm.generators.mkImpureConfigMerger {
        inherit pkgs path;
        format = "json";
        empty = "{}";
        jqOperation = "$dynamic * $static";
        mode = "600";
        staticSettings = (pkgs.formats.json { }).generate name settings;
      }
    );
in
{
  aspects.nixos.workstation =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      sessionEnv = config.sops.templates."session.env";
    in
    {
      imports = [ inputs.paseo.nixosModules.paseo ];
      services.paseo = {
        enable = true;
        package = paseoFor pkgs;
        user = username;
        group = config.users.users.${username}.group;
        relay.enable = false;
        # 上游只加 profile，缺少 HM sessionPath 里的 mise shims。
        inheritUserEnvironment = false;
      };
      systemd.services.paseo = {
        after = [
          "sops-install-secrets.service"
          "home-manager-${username}.service"
        ];
        unitConfig.ConditionPathExists = sessionEnv.path;
        serviceConfig.EnvironmentFile = sessionEnv.path;
        environment.PATH = lib.mkForce (
          import ./_service-path.nix lib config.home-manager.users.${username}.home
        );
      };
      sops.templates."session.env".restartUnits = [ "paseo.service" ];
    };

  aspects.nixos.desktop =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.paseo-desktop
      ];
    };

  # macOS cask 同时提供桌面端和 paseo CLI。
  aspects.darwin.desktop.homebrew.casks = [ "paseo" ];

  aspects.homeManager.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      appData =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "${config.home.homeDirectory}/Library/Application Support"
        else
          config.xdg.configHome;
    in
    {
      home.activation.paseoDesktopClient =
        mergeSettings lib pkgs "${appData}/Paseo/desktop-settings.json" "paseo-desktop-settings.json"
          {
            settings.daemon.manageBuiltInDaemon = false;
          };
    };

  aspects.homeManager.workstation =
    {
      aiCatalog,
      config,
      lib,
      pkgs,
      withSessionEnv,
      ...
    }:
    {
      launchd.agents.paseo = {
        enable = true;
        config = {
          ProgramArguments = [
            (withSessionEnv "paseo-with-secrets" "exec ${lib.getExe' (paseoFor pkgs) "paseo-server"}")
          ];
          EnvironmentVariables.PATH = import ./_service-path.nix lib config.home;
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Interactive";
        };
      };

      # CLI 和桌面端都要写 config.json，登录信息和其他运行时设置随文件保留。
      home.activation.paseoConfig =
        mergeSettings lib pkgs "${config.home.homeDirectory}/.paseo/config.json" "paseo-config.json"
          {
            daemon = {
              listen = "127.0.0.1:6767";
              relay.enabled = false;
            };
            agents.providers.omp = {
              enabled = true;
              # omp 也会列出网关不提供的模型，默认选用与 omp.nix 相同的 Opus。
              additionalModels = [
                {
                  id = aiCatalog.ref "opus";
                  label = aiCatalog.models.opus.name;
                  isDefault = true;
                }
              ];
            };
          };
    };
}
