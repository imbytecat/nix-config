# treefmt 配置（由 flake.nix 的 formatter/checks 消费）。
# 只接 nix：Markdown/JSON 交给 prettier 之类会把现有中文文档全量重排，diff 噪音不抵收益。
# 需要时再逐个 programs.<fmt>.enable = true 打开，treefmt 自带 100+ formatter。
{
  projectRootFile = "flake.nix";
  programs.nixfmt.enable = true;
  settings.global.excludes = [
    "result/**"
    ".direnv/**"
  ];
}
