# mise 恢复方案调查

调查日期：2026-07-10。仓库当前锁定 Home Manager `144f4e36d0186195037da9fce80a727108978070`、nixpkgs `f205b5574fd0cb7da5b702a2da51507b7f4fdd1b`；后者提供 mise `2026.7.0`（见 `flake.lock:256-268`、`flake.lock:445-452` 与 [nixpkgs 包定义](https://github.com/NixOS/nixpkgs/blob/f205b5574fd0cb7da5b702a2da51507b7f4fdd1b/pkgs/by-name/mi/mise/package.nix#L23-L34)）。

## 结论

- 恢复 Home Manager 的 `programs.mise`，删除 `proto` 包和手写的 Fish 激活。无需显式设置 `enableFishIntegration = true`。
- NixOS 已启用 `nix-ld`，应保留 `settings.all_compile = false` 以使用预编译 runtime；不需要再设置 `MISE_NODE_COMPILE` 或 `MISE_PYTHON_COMPILE`。
- 若用户明确要信任所有配置，官方写法是 `trusted_config_paths = [ "/" ]`。它不支持通配符；`/` 本身即可匹配所有绝对路径。
- 信任 `/` 等价于关闭 mise 的信任机制。更安全的默认值仍是只列自己控制的工作区根目录。

## Home Manager 当前接口与激活行为

锁定版本提供这些选项：

- `programs.mise.enable`
- `programs.mise.package`，默认使用 `pkgs.mise`，也允许设为 `null`
- `enableBashIntegration`、`enableFishIntegration`、`enableZshIntegration`、`enableNushellIntegration`
- `globalConfig`，生成 `$XDG_CONFIG_HOME/mise/config.toml`

启用后，Home Manager 会安装 mise 和补全所需的 `usage`；Fish 配置中注入 `${mise}/bin/mise activate fish | source`。各 shell 集成选项继承 `home.shell.enable<SHELL>Integration`，而其全局默认值为 `true`，因此本仓不应重复写 `enableFishIntegration = true`。

来源：[Home Manager mise 模块](https://github.com/nix-community/home-manager/blob/144f4e36d0186195037da9fce80a727108978070/modules/programs/mise.nix#L40-L147)、[集成选项默认值](https://github.com/nix-community/home-manager/blob/144f4e36d0186195037da9fce80a727108978070/modules/lib/shell.nix#L5-L23)、[全局 shell 集成默认开启](https://github.com/nix-community/home-manager/blob/144f4e36d0186195037da9fce80a727108978070/modules/misc/shell.nix#L10-L33)。

`mise activate` 会在每次显示提示符时运行 `mise hook-env`，动态增删 PATH 和相关环境变量；没有项目 mise 配置时，本仓由 Nix 安装的 `bun`、`go`、`nodejs`、`python3` 仍是全局后备，进入带 mise 配置的项目后才由 mise 管理的版本覆盖。来源：[mise FAQ](https://github.com/jdx/mise/blob/v2026.7.0/docs/faq.md#L27-L67)。

## 预编译 runtime

`all_compile` 仍然存在。它通常默认 `false`，但 mise 在 NixOS 和 Alpine 上会把默认值改成 `true`；为 `true` 时，会在未显式配置语言级选项的情况下，将 Node、Python、Erlang、Ruby 的 `compile` 设为 `true`。mise 官方 Nix 安装文档明确建议：NixOS 若要使用预编译二进制，应启用 `nix-ld` 并禁用 `all_compile`。

来源：[all_compile 定义](https://github.com/jdx/mise/blob/v2026.7.0/settings.toml#L59-L72)、[NixOS 默认值](https://github.com/jdx/mise/blob/v2026.7.0/src/config/settings.rs#L207-L215)、[对语言级设置的影响](https://github.com/jdx/mise/blob/v2026.7.0/src/config/settings.rs#L407-L423)、[官方 Nix 安装提示](https://github.com/jdx/mise/blob/v2026.7.0/docs/installing-mise.md#L273-L287)。

因此本仓推荐：

```nix
programs.mise = {
  enable = true;
  globalConfig.settings = {
    all_compile = false;
  };
};
```

无需另设 `MISE_NODE_COMPILE=0` 或 `MISE_PYTHON_COMPILE=0`。`all_compile = false` 的语义是“不要全局强制源码编译”，语言级设置未定义时采用“优先预编译，缺失时回退源码编译”。若要求“绝不源码编译，缺少二进制就失败”，才应显式设置 `node.compile = false`、`python.compile = false`（或对应环境变量）。

来源：[Node compile 设置](https://github.com/jdx/mise/blob/v2026.7.0/settings.toml#L1535-L1539)、[Node 的三态处理](https://github.com/jdx/mise/blob/v2026.7.0/src/plugins/core/node.rs#L107-L141)、[Python compile 设置](https://github.com/jdx/mise/blob/v2026.7.0/settings.toml#L1902-L1912)。Darwin 不会触发 NixOS 的 `all_compile = true` 默认值，但共享配置中显式写 `false` 无害，并保证两端语义一致。

## 信任所有配置

官方支持三种全局表达：

```toml
[settings]
trusted_config_paths = ["/"]
```

```sh
MISE_TRUSTED_CONFIG_PATHS=/
```

```sh
mise settings set trusted_config_paths /
```

本仓由 Home Manager 管理全局配置，应使用第一种的 Nix 表达，不要再用 CLI 修改同一个只读、声明式生成的文件：

```nix
globalConfig.settings.trusted_config_paths = [ "/" ];
```

`trusted_config_paths` 是仅允许出现在全局配置中的路径列表；环境变量在 Unix 用 `:`、Windows 用 `;` 分隔多条路径。官方说明 `["/"]` 会“有效禁用信任机制”。来源：[设置定义](https://github.com/jdx/mise/blob/v2026.7.0/settings.toml#L2635-L2646)、[CLI 对路径列表的解析](https://github.com/jdx/mise/blob/v2026.7.0/src/cli/settings/set.rs#L42-L66)。

它不支持 glob。实现会规范化每个目录，然后用 `Path::starts_with` 判断配置文件是否位于该目录下；所以填写父目录已自动覆盖全部后代，`*` 或 `/**` 会被当作普通路径字符，而 `/` 会覆盖 Unix 上的全部绝对路径。来源：[路径规范化](https://github.com/jdx/mise/blob/v2026.7.0/src/config/settings.rs#L669-L675)、[前缀匹配](https://github.com/jdx/mise/blob/v2026.7.0/src/config/config_file/mod.rs#L365-L375)。

安全影响不可忽略：mise 只会无条件读取由纯版本号组成的 `[tools]`、无模板/工具选项的 `[tasks]` 等安全子集；环境变量、hooks、settings、aliases、templates 和工具选项均需要信任，因为配置在加载时可能执行代码或影响当前 shell 环境。信任 `/` 后，进入任意不受控制的仓库都会跳过这层确认。来源：[信任命令说明](https://github.com/jdx/mise/blob/v2026.7.0/docs/cli/trust.md#L7-L20)、[信任问题说明](https://github.com/jdx/mise/blob/v2026.7.0/docs/faq.md#L242-L268)。

## 对旧配置的具体改进

推荐恢复为：

```nix
{ ... }:

{
  programs.mise = {
    enable = true;
    globalConfig.settings = {
      all_compile = false;
      trusted_config_paths = [ "/" ];
    };
  };
}
```

相较旧实现：

- 使用正式 Home Manager 模块，不把 mise 放进 `home.packages`，也不手写 Fish 激活。
- 不重复声明默认开启的 Fish 集成。
- 用当前仍受支持的 `all_compile = false` 统一处理 NixOS 预编译，不增加语言级环境变量。
- “信任所有”直接用根路径，不使用无效的通配符。
- 保留 Nix 安装的常用 runtime 作为无项目配置时的全局默认；mise 负责项目级覆盖。
