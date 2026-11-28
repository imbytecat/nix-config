{ inputs, ... }:

let
  file = ../secrets/workstation.yaml;
  identity = "/var/lib/sops-nix/key.txt";
  # Darwin 先激活 HM 再解密。路径随密文变化，让 launchd 重启后只可能读到本代文件。
  darwinEnv = "session-${builtins.substring 0 16 (builtins.hashFile "sha256" file)}.env";

  # 一个接收者解密整份密文；各 feature 在自己的文件里声明要用的 sops.secrets。
  common =
    envName:
    { config, username, ... }:
    {
      sops = {
        defaultSopsFile = file;
        age.keyFile = identity;
        age.sshKeyPaths = [ ];
        gnupg.sshKeyPaths = [ ];

        secrets = {
          "agents.env".owner = username;
          "workstation.env".owner = username;
        };

        # 两段保持 shell 与 systemd 都能读的 dotenv 格式。
        templates.${envName} = {
          owner = username;
          content = config.sops.placeholder."agents.env" + "\n" + config.sops.placeholder."workstation.env";
        };
      };

      # 交互 shell 与 agent 服务读同一份会话 env。
      home-manager.extraSpecialArgs.sessionEnvFile = config.sops.templates.${envName}.path;
    };
in
{
  aspects.nixos.workstation =
    { username, ... }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
        (common "session.env")
      ];
      # 首装不向 kexec 安装器传密钥；第一次 switch/deploy 会在正式系统上写入。
      sops.useSystemdActivation = true;
      systemd.services.sops-install-secrets.unitConfig.ConditionPathExists = identity;
      systemd.services."home-manager-${username}".after = [ "sops-install-secrets.service" ];
    };

  aspects.darwin.workstation.imports = [
    inputs.sops-nix.darwinModules.sops
    (common darwinEnv)
  ];

  aspects.homeManager.workstation =
    {
      lib,
      pkgs,
      sessionEnvFile,
      ...
    }:
    {
      # launchd 没有 EnvironmentFile。与交互 zsh 一样由 shell 解释 dotenv，不开 nounset。
      _module.args.withSessionEnv =
        name: command:
        lib.getExe (
          pkgs.writeShellApplication {
            inherit name;
            bashOptions = [
              "errexit"
              "pipefail"
            ];
            text = ''
              set -a
              # shellcheck source=/dev/null
              source ${lib.escapeShellArg sessionEnvFile}
              set +a
              ${command}
            '';
          }
        );

      # 放在最后，覆盖 local.zsh 等先前 export 的同名变量。
      programs.zsh.initContent = lib.mkAfter ''
        if [[ -r ${sessionEnvFile} ]]; then
          set -a
          source ${sessionEnvFile}
          set +a
        fi
      '';
    };
}
