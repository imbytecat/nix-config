# 仅格式化 Nix，避免无关文档全量重排。
{
  projectRootFile = "flake.nix";
  programs.nixfmt.enable = true;
  settings.global.excludes = [
    "result/**"
    ".direnv/**"
  ];
}
