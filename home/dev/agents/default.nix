{ inputs, system, ... }:

{
  imports = [
    ./claude-code.nix
    ./codex.nix
    ./omp.nix
  ];

  # 上游推荐直接吃 packages（不 follows nixpkgs，命中 cache.numtide.com）
  # agent-browser：wrapper 已自带 chromium env，开箱即用（跨平台）。
  home.packages = with inputs.llm-agents.packages.${system}; [
    skills
    agent-browser
  ];
}
