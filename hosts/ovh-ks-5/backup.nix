{
  config,
  pkgs,
  ...
}:

let
  stacksDir = "/opt/stacks";
  dumpsDir = "${stacksDir}/.dumps";
  docker = "${config.virtualisation.docker.package}/bin/docker";
in
{
  systemd.tmpfiles.rules = [ "d ${stacksDir} 0755 root root -" ];

  # 口径沿用 dockge 的"整棵目录打包"：所有 bind mount 都在 stacksDir 内，逻辑 dump 也写进去，
  # 于是单个 snapshot 就是一台可搬走的机器。
  #
  # 手写在机器上的只有 /etc/restic/{repository,password,env}（同 /etc/mihomo/env 的取舍）。
  # repository 用 sftp://user@host:port//abs/path 整条 URL，端口也在里面，因此不需要
  # /root/.ssh/config 别名——本仓公开，主机名/用户名/端口都不该进 git。
  services.restic.backups.stacks = {
    repositoryFile = "/etc/restic/repository";
    passwordFile = "/etc/restic/password";
    environmentFile = "/etc/restic/env";
    initialize = true;

    # 空 known_hosts 的新机器上，默认的 StrictHostKeyChecking=ask 在单元里等于直接失败。
    # accept-new 只在首连信任一次：真被中间人换掉主机密钥，publickey 认证会失败（签名绑定
    # session id），结果是备份报错而不是数据外泄。
    extraOptions = [ "sftp.args='-o StrictHostKeyChecking=accept-new'" ];

    paths = [
      stacksDir
      # named volume 也只是目录；顺手兜住 bind mount 之外的写法
      "/var/lib/docker/volumes"
    ];
    exclude = [ "/var/lib/docker/volumes/backingFsBlockDev" ];

    # tar 一个活着的 PG 数据目录只是崩溃一致；能保证恢复的是逻辑 dump。
    # pg_dumpall 连 role 和密码一起带走，恢复端不用重配账号。
    backupPrepareCommand = ''
      #!${pkgs.runtimeShell}
      set -euo pipefail

      rm -rf ${dumpsDir}
      mkdir -p ${dumpsDir}
      chmod 700 ${dumpsDir}

      for id in $(${docker} ps -q); do
        ${docker} exec "$id" sh -c 'command -v pg_dumpall >/dev/null 2>&1' || continue
        name=$(${docker} inspect -f '{{.Name}}' "$id" | tr -d /)
        user=$(${docker} exec "$id" printenv POSTGRES_USER 2>/dev/null || echo postgres)
        pass=$(${docker} exec "$id" printenv POSTGRES_PASSWORD 2>/dev/null || true)
        if ! ${docker} exec -e PGUSER="$user" -e PGPASSWORD="$pass" "$id" \
             pg_dumpall --clean --if-exists \
             | ${pkgs.zstd}/bin/zstd -q -f -o ${dumpsDir}/"$name".sql.zst; then
          echo "pg_dumpall 失败: $name" >&2
          touch ${dumpsDir}/FAILED-"$name"
        fi
      done
    '';

    # 先让快照照常落地（残缺也比没有强），再把单元标红——绿色的残缺备份才是真事故。
    backupCleanupCommand = ''
      #!${pkgs.runtimeShell}
      for f in ${dumpsDir}/FAILED-*; do
        [ -e "$f" ] || continue
        echo "dump 失败，本次快照不含完整数据库: $f" >&2
        exit 1
      done
    '';

    pruneOpts = [
      "--keep-daily 14"
      "--keep-weekly 8"
      "--keep-monthly 12"
    ];

    # 每次跑抽检 2%，约 50 天覆盖整个仓库，不用另排校验计划。
    checkOpts = [ "--read-data-subset=2%" ];

    timerConfig = {
      OnCalendar = "04:00";
      RandomizedDelaySec = "30m";
      Persistent = true;
    };
  };
}
