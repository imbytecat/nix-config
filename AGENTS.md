# AGENTS.md — Arch Linux 声明式配置仓库

## 概要

使用 [decman](https://github.com/kiviktnm/decman) 声明式管理 Arch Linux 系统配置。Python 源文件声明包、系统文件、dotfiles 和 systemd 服务。

- **运行环境**：Arch Linux（主要面向 WSL，兼容裸机）
- **语言**：Python（配置）、Bash（引导脚本）
- **包管理器**：uv（开发依赖）、pacman/yay（系统包）

## 仓库结构

```
.
├── source.py            # decman 主配置入口
├── locale_module.py     # locale 模块（files + on_change hook）
├── docker_module.py     # Docker 模块（packages + systemd units）
├── system/etc/          # 系统配置文件源 → 部署到 /etc/
├── home/                # 用户配置文件源 → 部署到 ~/
├── scripts/
│   ├── install.sh       # 引导脚本（git → yay → decman → 首次 sync）
│   └── wsl-init.sh      # WSL 首次初始化（创建用户）
└── pyproject.toml       # 开发依赖（decman + 插件，仅用于类型检查）
```

## 命令

```bash
# 应用配置（安装/更新包、同步文件、启用服务）
sudo decman

# 首次运行（需指定 source 路径）
sudo decman --source ~/.config/archlinux-config/source.py

# 跳过特定插件
sudo decman --skip aur
sudo decman --skip systemd

# 仅同步文件
sudo decman --no-hooks --only files

# 调试模式
sudo decman --debug
```

### 验证

```bash
# Python 语法检查（所有 .py 文件）
python -c "import py_compile; py_compile.compile('source.py', doraise=True)"
python -c "import py_compile; py_compile.compile('docker_module.py', doraise=True)"
python -c "import py_compile; py_compile.compile('locale_module.py', doraise=True)"

# Shell 语法检查
bash -n scripts/install.sh
bash -n scripts/wsl-init.sh

# 同步开发依赖
uv sync
```

## decman 执行顺序

声明顺序必须匹配执行顺序，从上到下阅读即从上到下执行：

```
files → pacman → aur → systemd
```

`source.py` 中的声明分区按此排列：系统文件 → 用户配置 → modules → pacman 包 → AUR 包。

## 代码风格

### Python（source.py 及模块）

**source.py 结构**：
- 用 `# ── Section ──` 分隔逻辑分区
- 包集合用 `|=` 语法，元素按字母排序
- `SUDO_USER` 必须存在，不设 fallback——没有则抛 `SourceError`
- 文件默认权限 `0o644`，仅需特殊权限时显式指定（如 sudoers `0o440`）

**模块模式**（适用于需要 hook 或跨步骤声明的场景）：
```python
from decman import Module
from decman.plugins.pacman import packages
from decman.plugins.systemd import units

class DockerModule(Module):
    def __init__(self):
        super().__init__("docker")

    @packages
    def packages(self) -> set[str]:
        return {"docker", "docker-compose"}

    @units
    def units(self) -> set[str]:
        return {"docker.service"}
```

**何时用模块 vs 直接声明**：
- 需要 `on_change` hook（如 `locale-gen`）→ Module
- 需要绑定 packages + systemd units → Module（`@packages` + `@units` 装饰器）
- 纯静态文件、无副作用 → 直接在 `source.py` 用 `File()`

### Shell 脚本

- Shebang：`#!/bin/bash`
- 安全选项：`set -euo pipefail`
- 变量引用：始终加双引号 `"$VAR"`
- 条件测试：优先 `[[ ]]`
- 命令检测：`if command -v cmd &> /dev/null; then`
- 用户消息：中文，用 `echo "==> 动作..."` 标记主要步骤，`✓` 表示完成
- 错误消息：`echo "错误：描述"` + `exit 1`

### Git

- 提交消息：中文，conventional commits 格式
- 格式：`<type>(<scope>): <中文描述>`
- 类型：`feat` / `fix` / `docs` / `refactor` / `chore`
- 示例：`feat(docker): 添加 Docker 支持并重排声明顺序`
- 分支：直接在 `main` 上工作

## Agent 须知

1. **decman 是唯一真相**：不要手动装包，加到 `source.py` 或模块里，跑 `sudo decman`。

2. **Pacman vs AUR**：用 `pacman -Ss` 确认包在官方仓库还是 AUR，分别加到 `decman.pacman.packages` 或 `decman.aur.packages`。

3. **系统文件**：源文件放 `system/`，目录结构对应目标路径（`system/etc/foo.conf` → `/etc/foo.conf`）。decman 复制（非 symlink）到目标位置。

4. **用户配置**：源文件放 `home/`，必须指定 `owner=USERNAME`。

5. **Runs as root**：`sudo decman` 以 root 执行 `source.py`。`SUDO_USER` 是调用 sudo 的原始用户名，不要 fallback。

6. **开发环境**：`pyproject.toml` + `uv sync` 管理开发依赖（decman、decman-pacman、decman-systemd），仅用于 IDE 类型检查，不影响运行时。

7. **幂等性**：所有脚本和配置必须可安全重复执行。

8. **语言**：用户消息、文档、提交消息使用中文。

## 常见任务

**添加包**：确认 pacman/AUR → 加到 `source.py` 对应集合 → `sudo decman`

**添加系统文件**：放 `system/` → 在 `source.py` 加 `File(source_file=...)` → `sudo decman`

**添加 dotfile**：放 `home/` → 在 `source.py` 加 `File(source_file=..., owner=USERNAME)` → `sudo decman`

**添加需要 systemd 服务的软件**：创建 Module 文件，用 `@packages` + `@units` 装饰器 → 在 `source.py` 注册 → `sudo decman`

**添加开发依赖（decman 插件）**：加到 `pyproject.toml` 的 `[dependency-groups] dev` 和 `[tool.uv.sources]` → `uv sync`
