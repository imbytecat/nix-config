# 每个 bundle 按 agent 分键（codex / claude / omp / skills）；这里按键取列，映射文件只读自己那一列。
args:
let
  bundles = [
    (import ./caveman.nix args)
    (import ./ponytail.nix args)
  ];
  column = key: map (bundle: bundle.${key}) (builtins.filter (bundle: bundle ? ${key}) bundles);
in
{
  codex = column "codex";
  claude = column "claude";
  omp = column "omp";
  skills = builtins.foldl' (all: skills: all // skills) { } (column "skills");
}
