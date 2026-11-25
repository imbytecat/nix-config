{
  aspects.homeManager.daily =
    {
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      agentPackages = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      _module.args.aiCatalog = import ./_ai-catalog.nix {
        inherit lib;
        modelsDev = inputs.models-dev;
      };

      # 直接使用上游 packages，保留 cache.numtide.com 命中。
      home.packages = [
        pkgs.nodejs # Codex 和 Claude 插件的 hooks 用 node 执行。
        agentPackages.skills
        agentPackages.agent-browser
      ];
    };
}
