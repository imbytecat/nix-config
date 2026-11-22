# 开发语言工具调研：`modules/dev/languages.nix` 里谁在用什么（2026-11-15）

## 结论

运行时基本都在被 agent 高频使用，全部保留（`fvm`、`typst` 视情况）。LSP 和格式化器里，大多数**只有在没人打开的地方才是“被配置”的**：

- **VS Code 不依赖 PATH 上的大多数 LSP。** YAML、Dockerfile、Vue、TypeScript 都由扩展自带服务器；Ruff 找不到 PATH 版本时回退到扩展自带的二进制。真正从 PATH（或写死的 HM 路径）取二进制的只有：`biome`（`settings.json` 写死 `/etc/profiles/per-user/imbytecat/bin/biome`）、`gopls`（vscode-go 查找顺序最后落到 PATH）、`just-lsp`（just 扩展默认命令）、`nixd` + `nixfmt`（仅 nix-config 的 `.vscode/settings.json`）。
- **LazyVim 实际几乎不用。** Mac 上最后一次使用是 2026-10-25，PC 上是 2026-08-18。两台机器都只用它编辑过配置文件（`known_hosts`、`nix.conf`、`.env`、`mise.toml` 等）。它启用的 extras 里，`nil`、`vtsls`、`pyright`、`hadolint`、`gofumpt`、`goimports`、`golangci-lint` 都没有安装。HM 装的 `nixd`、`typescript-language-server`、`vue-language-server`、`bash-language-server`、`just-lsp`、`biome` 又都没被 LazyVim 配置。
- **omp 的 `lsp` 工具从未被显式调用**（两台机器 0 次），只在 write/edit 后自动跑诊断。有记录的诊断来源只有 `nixd`、`biome`、`typescript-native`（项目自带的 TS 7 `tsc`）和 `gopls`。`lsp.formatOnWrite` 默认是 `false`，本机也没有改，所以 omp 写文件后不运行格式化器。Codex CLI 和 DSH 没有 LSP 或写后格式化。
- **agent 直接调用格式化器或 linter 的次数很少。** `shellcheck` 有 49 次（Codex，Mac）；`biome` 有 49 次，几乎全是 `bunx` 或 `node_modules/.bin`，即项目本地版本；`ruff` 有 4 次，全是 `uv run`，即项目本地版本；`statix` 有 1 次。`nixfmt`、`statix` 的实际调用都走 `nix fmt`、`just lint` 和 `nix flake check`，用的是 flake 自己的包，不是 HM 里的版本。

| 工具 | 类别 | VS Code | LazyVim | omp / agents | 实测使用 | 结论 |
|---|---|---|---|---|---|---|
| `bun` | 运行时 | `oven.bun-vscode` 调运行时 | — | 高频 bash 调用 | PC omp 1791 次（最后 10-06）；Mac Codex 486 次（09-21）；Mac omp `bunx` 8 次（11-15）；5–6 个项目有 `bun.lock` | **保留**：JS 项目的主运行时 |
| `go` | 运行时 | vscode-go 需要 | `lang.go` 的 gopls 运行时 | 高频 | Mac omp 125 次（11-15）、Codex 258 次、DSH 97 次；PC omp 110 次 | **保留**：3 个 Go 项目在用 |
| `nodejs` | 运行时 | — | — | `node`/`npm`/`npx` | PC omp `node` 88 次（11-10）；Mac omp `npm` 10 次（11-15） | **保留**：npm 查询与脚本常用 |
| `python3` | 运行时 | Python 扩展解释器 | — | 最高频的临时脚本工具 | Mac DSH 727 次（11-14）、Codex 377 次、omp 34 次（11-15）；PC omp 163 次（11-01） | **保留** |
| `typst` | 运行时 | tinymist 扩展自带二进制 | 未启用 `lang.typst` | 只在 PC 上用过 | PC omp 55 次（最后 09-11）、Codex 13 次；Mac 0 次；`edu-spark` 用 mise 固定 0.15.1 | **视情况**：只有临时排版合同时才需要全局版本 |
| `uv` | 运行时 | — | — | venv、`uv run` | PC omp 45 次（11-01）+ `uvx` 8 次；Mac 1 次（10-28） | **保留**：Python 环境入口 |
| `fvm` | 运行时 | — | — | 0 次 | 唯一的 Flutter 项目 `aima-lite`（`.fvmrc` 指定 3.44.2）；`~/fvm/versions` 停在 2026-07-01 | **视情况**：7 月后没人用 |
| `android-tools` | 运行时 | — | — | `adb`/`fastboot` | Mac DSH `adb` 1945 次（11-07）、omp 237 次；PC omp `adb` 27 次（11-10）、`fastboot` 28 次 | **保留**：最高频的外部工具之一 |
| `mise` (`programs.mise`) | 运行时管理 | `hverlin.mise-vscode` | — | 高频 | Mac Codex 608 次、omp 298 次（11-12）；PC omp 458 次（11-10）；6–9 个项目有 `mise.toml` | **保留** |
| `bash-language-server` | LSP | 未装 Bash IDE 扩展 | 未配置（`bashls` 只在未启用的 `util.dot` extra 里） | omp `bashls` 可自动启用 | 14 次 `.sh` 写入，0 条诊断；0 次 bash 调用 | **可删** |
| `dockerfile-language-server` | LSP | Container Tools 扩展自带 | `lang.docker` 配置了 `dockerls` | omp 有 `dockerls` | 0 条诊断，0 次调用；LazyVim 从没打开过 Dockerfile | **可删** |
| `gopls` | LSP | vscode-go 经 PATH 找到它（`~/go/bin` 不存在） | `lang.go` 配置了 `gopls` | omp 有 `gopls` | PC omp 写后诊断 3 次（08-17，`label-printer-web`） | **保留**：唯一同时服务三方的 LSP |
| `just-lsp` | LSP | `nefrob.vscode-just-syntax` 默认命令 `just-lsp` | 未配置 | omp 没有内置 just 服务器 | VS Code 日志 0 次命中；4–5 个仓库有 `justfile` | **视情况**：唯一消费者是 VS Code 的 just 扩展 |
| `lua-language-server` | LSP | 未装 Lua 扩展 | 核心配置启用了 `lua_ls` | omp 有，但需要 `.luarc` 或 `stylua.toml` 作为根标记 | 所有项目 0 个 `.lua` 文件 | **可删** |
| `nixd` | LSP | 只在 nix-config 中，由 direnv 引入 devShell 版本 | 未配置（`lang.nix` 用 `nil_ls`） | omp 有 `nixd`，根标记是 `flake.nix` | omp 写后诊断 Mac 15 次（11-15）、PC 13 次（08-12），全在 nix-config | **视情况**：nix-config 内由 devShell 供给，HM 版只服务仓库外的 `.nix` |
| `typescript-language-server` | LSP | 不用（内置 tsserver + `native-preview` 自带 `tsc`） | 未配置（用 `vtsls`） | omp 在 TS ≤ 6 项目里选它 | 0 条诊断；TS 诊断全来自 `typescript-native`（24 次） | **视情况**：omp 在 TS 6 仓库唯一的 TS 服务器，但从未产出记录 |
| `vue-language-server` | LSP | Volar 扩展自带 | 未启用 `lang.vue` | omp 只处理 `.vue` | 所有项目 0 个 `.vue` 文件 | **可删** |
| `yaml-language-server` | LSP | redhat.vscode-yaml 自带 | `lang.yaml` 配置了 `yamlls` | omp 有 `yamlls` | 约 35 次 YAML 写入，0 条诊断；0 次调用 | **可删** |
| `biome` | 格式化 / lint | **`biome.lsp.bin` 写死 HM 路径** | 未启用 biome extra | omp 优先用项目 `node_modules/.bin`；agent 用 `bunx` | omp 诊断 Mac 2 次、PC 11 次；agent 调用 49 次，几乎都是 `bunx` | **视情况**：先删掉 VS Code 的 `biome.lsp.bin` 再删包 |
| `nixfmt` | 格式化 | nix-config 中 nixd 的 `formatting.command = ["nixfmt"]` 从 PATH 找 | `lang.nix` 用 conform 跑 `nixfmt` | `nix fmt` 用 treefmt 自己的包 | 直接调用 0 次；`nix fmt`/`just fmt` 共 157 次 | **保留**：devShell 不提供裸 `nixfmt`，VS Code 格式化依赖它 |
| `ruff` | 格式化 / lint | ruff 扩展先用 PATH，找不到时回退到自带版本 | `lang.python` 配置了 `ruff` | omp 的 `ruff` 需要 `pyproject.toml` 或 `ruff.toml` | VS Code 日志在用 HM 版本；agent 4 次，都是 `uv run`；所有项目都没有 `pyproject.toml` | **可删** |
| `shellcheck` | lint | 未装 Bash IDE 扩展 | 未配置（只在 `util.dot` 里） | agent 直接调用 | Mac Codex 49 次（最后 09-19，`ufi-mihomo`/`mihomoctl`） | **保留**：agent 真实在用，成本低 |
| `shfmt` | 格式化 | — | 核心 conform 配置 `sh = { "shfmt" }` | — | 0 次 | **可删** |
| `statix` | lint | — | `lang.nix` 用 nvim-lint 跑 `statix` | `just lint` 和 `nix flake check` 用 flake 自己的包 | HM 版直接调用 1 次（PC 08-03） | **可删** |
| `stylua` | 格式化 | — | 核心 conform 配置 `lua = { "stylua" }` | — | 0 次；0 个 `.lua` 文件 | **可删** |

## 方法

- 时间窗口：omp session 为 2026-07-27 → 11-15（Mac 192 个 JSONL，PC 474 个）。Codex 为 Mac 17 个、PC 38 个文件。DSH 为 Mac 25 个 session、PC 4 个（`session.v4.jsonl.zstd`）。
- **bash 计数**（`/tmp/toolcount.py`，两台机器各跑一次；PC 用 `ssh awesome-pc 'python3 -' < /tmp/toolcount.py`）：
  - 只读结构化命令字段，不扫正文，所以 prose 中提到的工具名不计数。omp 读 `toolCall.name == "bash"` 的 `arguments.command`。Codex 读 `function_call exec_command` 的 `cmd`，以及 `custom_tool_call exec` JS 里的 `cmd: "…"` 字面量。DSH 读 `tool/call` 中 `name == "bash"` 的 `arguments.command`。
  - 用 `shlex` 按 `| || && ; & ( ) 换行` 拆成简单命令。丢弃 heredoc 正文，但保留 `bash -s`/`ssh … <<EOF` 的正文，因为它们本身就是命令。剥掉 `VAR=`、`sudo`、`env`、`timeout`、`xargs`、`command` 等前缀，并递归进入 `bash -c`、`ssh host cmd` 和 `nix shell … -c`。
  - 取首个 token 的 basename 计数。`bunx X`、`npx X`、`uvx X`、`uv run X`、`mise exec -- X`、`pnpm exec X` 同时记为 `X`（via …）。`command -v X` 不计。`--version`/`--help` 单独标为 probe，表中数字包含 probe，但 probe 都只有个位数。
  - 局限：脚本内部调用的工具不归属到具体工具（例如 `just lint` 内部调 `statix`），这类调用单独统计 `nix fmt`/`just fmt|lint|check`。
- **omp 写后诊断**：统计 write/edit 的 `toolResult.details.diagnostics.server`（`/tmp/omp_diag.py`、`/tmp/probe8.py`）。
- **Neovim**：`find ~/.local/state/nvim ~/.local/share/nvim -newermt 2026-01-01` 看 mtime，再读 `lsp.log`。atuin 直接用 `sqlite3`/Python 只读查询 `history.db`。
- **VS Code**：`code --list-extensions --show-versions`；读扩展目录下的 `package.json` 与 `bundled/`、`dist/`；`grep` `~/Library/Application Support/Code/logs` 与 `~/.config/Code/logs`；用 `workspaceStorage/*/workspace.json` 的 mtime 判断最近打开的工作区。
- 上游源码按锁定版本读取：lazyvim-nix [`30f8896f`](https://github.com/pfassina/lazyvim-nix/tree/30f8896fa0728844905a2e34f55d93fa42e69bf9)；它锁定 LazyVim v16.0.1 [`99970099`](https://github.com/LazyVim/LazyVim/tree/999700997f72227187d49d8b92667183dc7fc809)（`data/plugins.json`）。两者都通过 `nix flake prefetch` 取得。

## VS Code

两台机器的扩展集合基本相同。Mac 是 1.146.0，PC 是 1.144.0。两台机器的用户 `settings.json` 内容一致，都不由本仓管理。

| 扩展 | 服务器 / 二进制来源 | 依据 |
|---|---|---|
| 内置 TypeScript + `typescriptteam.native-preview` | 自带。`"js/ts.experimental.useTsgo": true`，扩展 `lib/tsc` 是自带的 TS 7 二进制 | 本机 `ls …/native-preview-*/lib`；settings.json |
| `vue.volar` 3.3.9 | 自带 `dist/language-server.js` | 扩展目录 |
| `redhat.vscode-yaml` 2.0.0 | 自带：`dependencies.yaml-language-server = 2.0.0`，`dist/languageserver.js` | 扩展 `package.json` |
| `ms-azuretools.vscode-containers` 2.5.3（`vscode-docker` 只是壳） | 自带 `dist/dockerfile-language-server-nodejs` 与 `compose-language-service` | 扩展目录、`package.json` |
| `charliermarsh.ruff` | `ruff.importStrategy` 默认 `fromEnvironment`：先找解释器环境，再找 PATH，最后回退到自带的 `bundled/libs/bin/ruff` | 扩展 `package.json` 描述；Mac 日志 `Using environment executable: /etc/profiles/per-user/imbytecat/bin/ruff`、`Found Ruff 0.17.1` |
| `biomejs.biome` | **settings.json 写死** `biome.lsp.bin` 为 HM 路径（darwin-arm64/linux-x64），设置后不再自动查找 | [Biome 文档 `biome.lsp.bin`](https://biomejs.dev/reference/vscode/)；PC 日志 `Unshimmed Biome binary from "/etc/profiles/per-user/imbytecat/bin/biome"` |
| `golang.go` | 依次查找 `alternateTools` → `GOBIN` → `toolsGopath`/`GOPATH/bin` → `GOROOT` → PATH。`~/go/bin` 在两台机器都不存在，所以落到 HM 的 `gopls`。`go.toolsManagement.autoUpdate: true` 时缺失的工具会被装进 GOPATH | [vscode-go `pathUtils.ts`](https://github.com/golang/vscode-go/blob/master/extension/src/utils/pathUtils.ts)；`ls ~/go/bin` |
| `jnoortheen.nix-ide` | `nix.enableLanguageServer` 默认 `false`，`nix.serverPath` 默认 `nixd`，`formatterPath` 默认 `nixfmt`。只有 nix-config 的 `.vscode/settings.json` 开启了 LSP；nixd 的 `formatting.command` 从 PATH 找 `nixfmt` | 扩展 `package.json`；`.vscode/settings.json` |
| `mkhl.direnv` | 让 VS Code 进入 nix-config 的 devShell，因此在 nix-config 里 `nixd` 来自 devShell | PC 日志中 direnv 注入 `…nixd-2.9.3/bin` 的 `now:` 行 |
| `nefrob.vscode-just-syntax` | `vscode-just.lspPath` 默认 `just-lsp`，从 PATH 找 | 扩展 `package.json` 与 `dist/extension.js` |
| `myriad-dreamin.tinymist` | 自带 `out/tinymist` 二进制与 typstyle 格式化 | 扩展目录、`tinymist.formatterMode = typstyle` |
| `astral-sh.ty` | 自带 `bundled/` | 扩展目录 |
| Bash IDE、Lua、StyLua | **未安装**（两台机器都 `ls ~/.vscode/extensions \| grep -iE 'bash\|lua\|stylua\|shell'` 为空） | — |

使用强度：atuin 记录的 `code` 调用，Mac 35 次（最后 11-15），PC 32 次（最后 09-30）。`workspaceStorage` 30 天内有改动的工作区：Mac 4 个（nix-config、mg4-helper 等），PC 1 个（nix-config，10-31）。

## Neovim / LazyVim

### lazyvim-nix 怎么供给工具

- Mason 被整体禁用：`starter-patcher.nix` 写入 `{ "mason-org/mason.nvim", enabled = false }` 等三项（[L15-L18](https://github.com/pfassina/lazyvim-nix/blob/30f8896fa0728844905a2e34f55d93fa42e69bf9/nix/lib/starter-patcher.nix#L15-L18)），`plugin-overrides.nix` 同样禁用（[L3-L12](https://github.com/pfassina/lazyvim-nix/blob/30f8896fa0728844905a2e34f55d93fa42e69bf9/nix/plugin-overrides.nix#L3-L12)）。
- 自动安装只有两层：
  - `installCoreDependencies` 默认 `true`，只装 git、rg、fd、lazygit、fzf、curl（[options.nix L79-L90](https://github.com/pfassina/lazyvim-nix/blob/30f8896fa0728844905a2e34f55d93fa42e69bf9/nix/options.nix#L79-L90)）。
  - 每个 extra 的 `installDependencies`/`installRuntimeDependencies` 默认都是 `false`（[options.nix L173-L192](https://github.com/pfassina/lazyvim-nix/blob/30f8896fa0728844905a2e34f55d93fa42e69bf9/nix/options.nix#L173-L192)；[dependencies.nix L43-L72](https://github.com/pfassina/lazyvim-nix/blob/30f8896fa0728844905a2e34f55d93fa42e69bf9/nix/lib/dependencies.nix#L43-L72)）。本仓没有开启这两个选项，所以 `extraPackages` 只有核心 6 个，与已知的 eval 结果一致。
  - 即使开启也覆盖不全：`data/dependencies.json` 中 `lang.nix`、`lang.typescript`、`lang.yaml` 没有映射（为 `null`）。`lang.go` 会装 gopls、gofumpt、golangci-lint 等，`lang.python` 只装 ruff。
- Mason 不存在时，LazyVim 对每个已启用的 server 直接调用 `vim.lsp.enable`（[lsp/init.lua L238-L266](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins/lsp/init.lua#L238-L266)），二进制缺失就报错。Mac 的 `lsp.log` 在 2026-09-12 有一条 `invalid "vtsls" config … vtsls is not executable`。

### 各 extra 配置的工具（LazyVim v16.0.1）

| 来源 | LSP | 格式化 | Linter | 本机是否已装 |
|---|---|---|---|---|
| 核心 | `lua_ls`（[lsp/init.lua L117](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins/lsp/init.lua#L117)） | `lua=stylua`、`fish=fish_indent`、`sh=shfmt`（[formatting.lua L73-L77](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins/formatting.lua#L73-L77)） | `fish`（[linting.lua L11](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins/linting.lua#L11)） | 全部已装 |
| `lang.nix` | **`nil_ls`**（[nix.lua L14](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins/extras/lang/nix.lua#L14)） | `nixfmt`（L23） | `statix`（L32） | `nil` ✗；`nixfmt` ✓；`statix` ✓ |
| `lang.go` | `gopls`（[go.lua L16](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins/extras/lang/go.lua#L16)） | `goimports`、`gofumpt`（L128） | `golangcilint`（L119） | `gopls` ✓；其余 ✗ |
| `lang.typescript` | 默认 **`vtsls`**（[typescript/init.lua L4, L16-L19, L42-L47](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins/extras/lang/typescript/init.lua#L42-L47)），`ts_ls` 被显式禁用 | —（prettier 是另一个 extra） | — | `vtsls` ✗ |
| `lang.python` | `pyright` + `ruff`（[python.lua L9-L10, L57-L61](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins/extras/lang/python.lua#L57-L61)） | ruff LSP | ruff LSP | `pyright` ✗；`ruff` ✓ |
| `lang.yaml` | `yamlls`（[yaml.lua L21](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins/extras/lang/yaml.lua#L21)） | yamlls | — | ✓ |
| `lang.docker` | `dockerls`、`docker_compose_language_service`（[docker.lua L46-L47](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins/extras/lang/docker.lua#L46-L47)） | — | `hadolint`（L38） | `docker-langserver` ✓；compose LS ✗；`hadolint` ✗ |

“已装”一列用 `command -v` 逐个检查，两台机器结果相同。不一致的地方：

- HM 装了 `nixd`，extra 要的是 `nil_ls`。
- HM 装了 `typescript-language-server`，extra 要的是 `vtsls`。
- `vue-language-server`、`bash-language-server`、`just-lsp`、`biome`、`shellcheck` 不在任何已启用的 extra 里。`bashls` 和 `shellcheck` 只出现在未启用的 [`util/dot.lua` L16, L22](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins/extras/util/dot.lua#L16-L22) 中。

### 实际使用

| 指标 | awesome-macbook-air | awesome-pc |
|---|---|---|
| atuin `nvim …`（`history.db` 只读） | 11 次，最后 2026-10-25 | 3 次，最后 2026-08-18 |
| fish_history `nvim` | 8 | 2 |
| `vim`/`vi` | 0 | 0 |
| `undo/` 中的文件 | 7 个：`local.fish`、`nix.conf`、`known_hosts`、`config.json`、一个 JS 参考文件、`AGENTS.md`、`README.md` | 2 个：`.env`、`mise.toml` |
| `shada/main.shada` mtime | 2026-10-25 | 2026-08-18 |
| `$EDITOR` | `nvim`（`hm-session-vars.sh`，来自 `programs.neovim.defaultEditor`） | 同左 |
| 手动 `git commit`（不带 `-m`，会打开 `$EDITOR`） | atuin 记录中 0 次（`git commit` 总数也是 0） | 0 次 |

结论：Neovim 是偶尔用来改配置文件的编辑器，没有在代码项目里配合 LSP 使用过。`$EDITOR` 这条路径在 shell 历史里也没有被 `git commit` 触发过，因为提交都由 agent 带 `-m` 完成。[INFERENCE] 删除上面任何 LSP 或格式化器都不会影响这种用法。

## omp / Codex / DSH

- **omp（18.20.0）的服务器发现**：从内置 `defaults.json` 出发，只保留同时满足两个条件的服务器：cwd 含有根标记，且二进制能在项目本地 bin（`node_modules/.bin`、venv 等）或 `$PATH` 中解析到（omp 内置文档 `omp://lsp-config.md`，即上游 [`docs/lsp-config.md`](https://github.com/can1357/oh-my-pi/blob/main/docs/lsp-config.md)）。
  - [`defaults.json`](https://github.com/can1357/oh-my-pi/blob/main/packages/coding-agent/src/lsp/defaults.json) 覆盖了本仓的 `gopls`、`typescript-language-server`、`biome`（`isLinter`）、`vue-language-server`、`ruff`（`isLinter`）、`bashls`、`lua-language-server`、`yamlls`、`dockerls`、`nixd`。**不含 just-lsp**。
  - 根标记方面：`ruff` 需要 `pyproject.toml`、`ruff.toml` 或 `.ruff.toml`；`lua-language-server` 需要 `.luarc*` 或 `stylua.toml`；`bashls`、`yamlls` 只需要 `.git`。
  - TS 只保留一个服务器：项目 `tsc` 是 7+ 时用 `typescript-native`，否则用 `typescript-language-server`。
- **omp 写入行为**：`lsp.diagnosticsOnWrite` 默认 `true`，`lsp.formatOnWrite` 默认 `false`（`omp://settings.md`）。`~/.omp/agent/config.yml` 中没有任何 `lsp` 键（`grep -n lsp`），所以 **omp 不在写入时运行格式化器**，只跑诊断。
- **实测**：
  - 两台机器的 session 中 `lsp` 工具调用都是 0 次（按 `toolCall.name` 统计；Mac 最常用的是 read 5453、bash 1875、grep 1626 次）。
  - 写后诊断来源：Mac 为 nixd 15、biome 2、typescript-native 1；PC 为 typescript-native 23、nixd 13、biome 11、gopls 3。
  - `.sh`、`.yaml`、`.yml`、`.py` 写入从未带诊断。[INFERENCE] `bashls` 和 `yamlls` 即使被选中，也没有在等待窗口内返回结果，或者 omp 没有记录。
- **Codex CLI**（Mac 0.169.0，PC 0.166.0）：没有内置 LSP 客户端，上游请求仍在讨论（[openai/codex#8633](https://github.com/openai/codex/issues/8633)）。`~/.codex/config.toml` 中没有 formatter 或 lint hook，只有 caveman 和 ponytail 的 session hook。Mac 上有空的 `~/.codex/codex-lsp/daemon/v0.1.0/daemon.log`，以及 `lsp-install-decisions.json`（2026-07-01，拒绝了 dart）。当前 codex 二进制中 `strings | grep codex-lsp` 为 0。[INFERENCE] 它们是早期插件或实验的遗留。
- **DSH**（0.2.2-rc.3）：25 个 session 的工具调用全部是 `bash`/`write`/`read`/`edit`/`web_*`/`job_*` 等，没有 LSP 或格式化工具，`cordis.patch.yml` 中也没有相关项。

## agent 的 bash 调用明细

只列出非零项。来源按 omp / Codex / DSH 分开；日期是最后一次使用。

| 包 | 二进制 | Mac | PC |
|---|---|---|---|
| bun | `bun` / `bunx` | omp 1 / 8（11-15）；Codex 486（含 mise exec 171）/ 14（09-21） | omp 1791 / 296（10-06）；Codex 534 / 149（08-04） |
| go | `go` / `gofmt` | omp 125（11-15）/ 30；Codex 258 / 124（09-21）；DSH 97（11-01） | omp 110（10-06）/ 35（08-17） |
| nodejs | `node` / `npm` / `npx` | omp 7 / 10 / 2（11-15）；DSH 30 / 4（11-10） | omp 88（11-10）/ 41 / 4 |
| python3 | `python3` | omp 34（11-15）；Codex 377；DSH 727（11-14） | omp 163（11-01）+ venv 中的 `python` 410；Codex 6；DSH 4 |
| typst | `typst` | 0 | omp 55（09-11）；Codex 13（08-03） |
| uv | `uv` / `uvx` | omp 1（10-28）；Codex 9（07-05） | omp 45（11-01）/ 8；DSH 2 |
| android-tools | `adb` / `fastboot` | omp 237（10-31）；DSH 1945 / 67（11-07）；Codex 14 | omp 27（11-10）/ 28（10-31） |
| mise | `mise` | omp 298（11-12）；Codex 608；DSH 72 | omp 458（11-10） |
| biome | `biome` | omp 2（项目本地 / `bunx`，11-15） | omp 45（44 次 `bunx`，08-18）；Codex 2（`bunx`） |
| ruff | `ruff` | 0 | omp 4（全是 `uv run --no-sync ruff`，11-01） |
| shellcheck | `shellcheck` | Codex 49（09-19） | 0 |
| statix | `statix` | 0 | omp 1（08-03） |
| 间接调用 | `nix fmt` / `just fmt` / `just lint` / `just check` / `nix flake check` | omp 9 / 20 / 11 / 13 / 6 | omp 35 / 93 / 10 / 136 / 18 |
| 各 LSP 二进制、`nixfmt`、`shfmt`、`stylua`、`fvm` | — | 0 | 0 |

## 运行时与项目

`~/Developer/*/*` 中的 git 仓库，用 `/tmp/projscan.py` 检查标记文件：

- Mac 10 个：bun 3、Go 1（mise 固定 go 的另有 2 个）、Flutter 1（`aima-lite`）、mise 6、biome 4、justfile 4。
- PC 12 个：bun 5、Go 2、mise 9、biome 6、Docker 5。
- `.lua` 和 `.vue` 文件两台机器都是 0 个。
- 带 `pyproject.toml` 或 `ruff.toml` 的项目 0 个。
- `typst-docs` 的 devShell 自带 `tinymist` 和 `typstyle`；`edu-spark` 用 mise 固定 typst。
- 项目中的 TS 版本：PC 7 个 TS 项目里有 6 个是 TS 6；`voicepaste` 和 Mac 的 `surgio-store` 是 TS 7.0.2。

Mac 上 bash 登录 shell 的 PATH 中，mise shims 排在 HM 前面（`which -a bun go node shellcheck`），所以在项目里实际用的是 mise 版本。HM 版本是项目外的兜底。

## 可安全删除 / 保留 / 低成本缺口

**可安全删除**（现有用法无回归；代价列在括号里）：

- `bash-language-server`（omp 失去 `bashls`，但它从未产出过诊断）
- `dockerfile-language-server`（LazyVim 的 `dockerls` 失效；VS Code 自带）
- `lua-language-server`（LazyVim 核心 `lua_ls` 打开 `.lua` 时会报 not executable，与已有的 vtsls 报错同类）
- `vue-language-server`
- `yaml-language-server`（LazyVim 的 `yamlls` 失效；VS Code 自带）
- `ruff`（VS Code 回退到扩展自带版本；agent 走 `uv run`）
- `shfmt`、`stylua`（只有 LazyVim 核心 conform 引用它们）
- `statix`（`just lint` 和 `nix flake check` 用 flake 自己的包）

**视情况**：

- `biome`：先删除 VS Code `settings.json` 中的 `biome.lsp.bin` 和已弃用的 `biome.lspBin`，让扩展用项目的 `node_modules` 版本，然后再删包。
- `nixd`：如果总是经 direnv 进入 nix-config，可以删。
- `typescript-language-server`：omp 在 TS 6 仓库里唯一的 TS 服务器，但实测没有产出记录。
- `just-lsp`：只服务 VS Code 的 just 扩展。
- `fvm`、`typst`：低频。

**保留**：`bun`、`go`、`nodejs`、`python3`、`uv`、`android-tools`、`mise`、`gopls`、`nixfmt`、`shellcheck`。

**低成本缺口**：

1. LazyVim extras 期望的工具大量缺失：`nil`、`vtsls`、`pyright`、`gofumpt`、`goimports`、`golangci-lint`、`hadolint`、compose LS。Mac 的 `lsp.log` 已有 vtsls 报错。最省事的做法有两个：一是去掉没在 Neovim 里用到的 extras（实测全部没用到）；二是用 extra 的 `config` 把 `lang.nix` 改成 `nixd`、把 TS 改成已装的服务器。打开 `installDependencies` 帮助不大，因为 nix、ts、yaml 没有映射。
2. VS Code 的 Biome 被写死为 HM 2.6.5，而项目声明的是 `^2.4.13`、`^2.4.16`、`2.6.7`。编辑器和 `bunx biome` 可能给出不同结果。删除 `biome.lsp.bin` 后扩展会自动用项目版本（[Biome 文档](https://biomejs.dev/reference/vscode/)）。
3. nix-config 的 `.vscode/settings.json` 让 nixd 调用裸 `nixfmt`，devShell（`modules/flake/tooling.nix`）只提供 treefmt wrapper，不提供 `nixfmt`（`ls …-treefmt/bin` 只有 `treefmt`）。所以 VS Code 在仓库里格式化依赖 HM 的 `nixfmt`。如果想让仓库自给自足，把 `pkgs.nixfmt` 加进 devShell 即可。本次没有修改。
4. `settings.json` 中的 `go.toolsManagement.autoUpdate: true` 会在缺少工具时往 `~/go/bin` 安装二进制，目前两台机器都没有这个目录。删除 `gopls` 后，vscode-go 会提示自行 `go install`，绕开 Nix。

## 处理结果（2026-11-16）

- 删除 LazyVim：去掉 `lazyvim` flake input 与 `programs.lazyvim`，Neovim 改为原生 `programs.neovim`（仍是 `$EDITOR`，带 `vi`/`vim` 别名），配色跟随全仓 catppuccin。
- 删除 `lua-language-server`、`vue-language-server`、`shfmt`、`stylua`、`statix`：VS Code 不从 PATH 用它们，agent 也用不到；`shfmt`、`stylua`、`statix` 原本只服务 LazyVim。
- 保留 omp 会选用的 LSP（`bash-language-server`、`dockerfile-language-server`、`gopls`、`nixd`、`typescript-language-server`、`yaml-language-server`），VS Code just 扩展用的 `just-lsp`，以及 `biome`、`nixfmt`、`ruff`、`shellcheck`。
- `fvm` 保留：`aima-lite` 的 AGENTS.md 规定只用 `fvm flutter`，项目暂停不等于工具无用。`typst` 保留。
- devShell 加入 treefmt 用的同一份 `nixfmt`（上文缺口 3）：本仓里 VS Code 保存时的格式化结果与 `nix fmt`、CI 一致，不再取决于 Mac 的 `nixpkgs-unstable`。
- 后续（2026-11-22）：删除 `typst` 与 `fvm`，项目工具链改由各项目自己声明。typst-docs 改由 pandoc 内置的 typst 读取器直出 DOCX，不再调用 typst CLI（见该仓 AGENTS.md），edu-spark 已弃用，VS Code 的 tinymist 自带二进制；aima-lite 改在 `mise.toml` 固定 Flutter 3.44.2。
