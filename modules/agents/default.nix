{
  aspects.homeManager.daily =
    { inputs, pkgs, ... }:
    let
      agentPackages = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      _module.args.aiCatalog = import ./_ai-catalog.nix;

      # 直接使用上游 packages，保留 cache.numtide.com 命中。
      home.packages = [
        agentPackages.skills
        agentPackages.agent-browser
      ];
    };
}
