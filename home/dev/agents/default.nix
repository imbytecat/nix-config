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

  # 直接使用上游 packages，保留 cache.numtide.com 命中。
  home.packages = [
    agentPackages.skills
    agentPackages.agent-browser
  ];
}
