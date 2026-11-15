{ pkgs, inputs, ... }:

let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  # Darwin 不用 herdr-app cask：release 构建默认开遥测并自更新，Nix 构建两者皆无。
  environment.systemPackages = [
    llmAgents.herdr-app
    # 手机 app 与其他机器经 SSH 调 `hc`，必须在登录 PATH；缺了 herdr 会复制一份非 Nix 的 hc。
    llmAgents.herdr-core
  ];
}
