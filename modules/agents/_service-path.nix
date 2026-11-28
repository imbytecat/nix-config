# 服务不经 login shell，agent 需从工作站的 PATH 找到 mise shims、omp、codex 和 git。
lib: home:
lib.concatStringsSep ":" (
  map (lib.replaceStrings [ "$HOME" ] [ home.homeDirectory ]) home.sessionPath
  ++ [
    "${home.profileDirectory}/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ]
)
