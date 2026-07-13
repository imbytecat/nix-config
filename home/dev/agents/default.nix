{ inputs, system, ... }:

{
  imports = [
    ./browser.nix
    ./claude-code.nix
    ./codex.nix
    ./grok.nix
    ./opencode.nix
  ];

  # 上游推荐直接吃 packages（不 follows nixpkgs，命中 cache.numtide.com）
  home.packages = [ inputs.llm-agents.packages.${system}.skills ];
}
