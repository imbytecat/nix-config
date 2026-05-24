{ pkgs, ... }:

{
  imports = [
    ./claude-code.nix
    ./codex.nix
    ./opencode.nix
  ];

  # 跨所有 coding agent 共用的 skills 安装/管理 CLI（vercel-labs/skills）
  home.packages = [ pkgs.llm-agents.skills ];
}
