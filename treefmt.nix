# 只格式化代码；Markdown 等文档不进 treefmt，避免全量重排。
{
  projectRootFile = "flake.nix";
  programs = {
    nixfmt.enable = true;
    just.enable = true;
    ruff-format.enable = true;
    shfmt = {
      enable = true;
      indent_size = 2;
    };
  };
  settings.global.excludes = [
    "result/**"
    ".direnv/**"
  ];
}
