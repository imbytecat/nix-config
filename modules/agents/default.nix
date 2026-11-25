{
  aspects.homeManager.workstation =
    {
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      # 直接使用上游 packages，不加 overlay，保留 cache.numtide.com 命中。
      llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      aiCatalog = import ./_ai-catalog.nix {
        inherit lib;
        modelsDev = inputs.models-dev;
      };
    in
    {
      # 各 agent 映射文件共用的数据与包只在这里构造一次。
      _module.args = {
        inherit aiCatalog llmAgents;
        agentBundles = import ./_bundles { inherit inputs lib pkgs; };
        gatewayProviders = import ./_gateway-providers.nix { inherit aiCatalog lib; };
      };

      home.packages = [
        pkgs.nodejs # Codex 和 Claude 插件的 hooks 用 node 执行。
        llmAgents.skills
        llmAgents.agent-browser
      ];
    };
}
