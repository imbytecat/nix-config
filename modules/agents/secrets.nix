{ inputs, ... }:
let
  file = ../../secrets/agents.yaml;
  # Darwin 先激活 HM 再解密。路径随密文变化，让 launchd 重启后只可能读到本代文件。
  darwinEnv = "agents-${builtins.substring 0 16 (builtins.hashFile "sha256" file)}.env";
  identity = "/var/lib/sops-nix/agents-key.txt";

  secretsFor =
    owner: envName:
    { config, ... }:
    {
      sops = {
        defaultSopsFile = file;
        age.keyFile = identity;
        age.sshKeyPaths = [ ];
        gnupg.sshKeyPaths = [ ];

        secrets = {
          "agents.env" = { inherit owner; };
          "workstation.env" = { inherit owner; };
          "tea.yml" = {
            inherit owner;
            path = "${config.home-manager.users.${owner}.xdg.configHome}/tea/config.yml";
          };
        };

        templates.${envName} = {
          inherit owner;
          content = config.sops.placeholder."agents.env" + "\n" + config.sops.placeholder."workstation.env";
        };
      };

      home-manager.users.${owner} =
        {
          aiCatalog,
          config,
          lib,
          pkgs,
          ...
        }:
        let
          envFile = "/run/secrets/rendered/${envName}";
          # Codex 的 TUI 和 app-server 都读原生登录文件。密钥经 stdin 传入。
          login = pkgs.writeShellScript "codex-api-login" ''
            set -euo pipefail
            ${pkgs.coreutils}/bin/printenv ${aiCatalog.gateway.apiKeyEnv} | ${lib.getExe config.programs.codex.package} login --with-api-key
          '';
          launch = pkgs.writeShellScript "t3code-with-secrets" ''
            set -ea
            source ${envFile}
            set +a
            ${login}
            exec "$@"
          '';
        in
        {
          programs.zsh.initContent = ''
            if [[ -r ${envFile} ]]; then
              set -a
              source ${envFile}
              set +a
            fi
          '';
          systemd.user.services.t3code = {
            Unit.ConditionPathExists = envFile;
            Service = {
              EnvironmentFile = envFile;
              ExecStartPre = "${login}";
            };
          };
          launchd.agents.t3code.config.ProgramArguments = lib.mkBefore [ "${launch}" ];
        };
    };

  linuxFor = owner: {
    imports = [
      inputs.sops-nix.nixosModules.sops
      (secretsFor owner "agents.env")
    ];
    # 首装不向 kexec 安装器传密钥；第一次 switch/deploy 会在正式系统上写入。
    sops.useSystemdActivation = true;
    systemd.services.sops-install-secrets = {
      unitConfig.ConditionPathExists = identity;
      # 用户服务读不到 system 级 restartUnits；已登录的会话在解密成功后重新载入 dotenv。
      postStart = ''
        uid=$(id -u ${owner})
        if [ -S "/run/user/$uid/bus" ] && systemctl --user --machine=${owner}@.host cat t3code.service >/dev/null 2>&1; then
          systemctl --user --machine=${owner}@.host --no-block restart t3code.service
        fi
      '';
    };
    systemd.services."home-manager-${owner}".after = [ "sops-install-secrets.service" ];
  };
in
{
  aspects.nixos.workstation = { username, ... }: { imports = [ (linuxFor username) ]; };
  aspects.darwin.workstation = { username, ... }: {
    imports = [
      inputs.sops-nix.darwinModules.sops
      (secretsFor username darwinEnv)
    ];
  };
}
