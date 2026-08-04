{ inputs, system, ... }:

let
  agentPackages = inputs.llm-agents.packages.${system};
in
{
  imports = [
    ./codex.nix
    ./omp.nix
    ./skills.nix
  ];

  # 上游推荐直接吃 packages（不 follows nixpkgs，命中 cache.numtide.com）
  # agent-browser：wrapper 已自带 chromium env，开箱即用（跨平台）。
  home.packages = [
    agentPackages.skills
    agentPackages.agent-browser
  ];
}
