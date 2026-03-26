# AGENTS.md - Arch Linux Configuration Repository

## Project Overview

This is a declarative Arch Linux configuration repository managed by `decman` (Declarative package & configuration manager for Arch Linux). The project uses a Python source file to declare packages, system files, and dotfiles.

**Primary Tool**: `decman` - Declarative package & configuration manager for Arch Linux
**Target Environment**: Arch Linux (primarily WSL, but supports bare metal)
**Language**: Shell scripts (Bash), Python configuration (source.py)

## Repository Structure

```
.
├── source.py         # decman main configuration (packages, system files, dotfiles)
├── files/            # System configuration files to deploy
│   └── etc/
│       ├── pacman.d/mirrorlist
│       └── sudoers.d/10-wheel
├── dotfiles/         # User dotfiles to deploy
│   └── .zshrc
└── scripts/
    ├── install.sh    # Bootstrap script (git → yay → decman → first sync)
    └── wsl-init.sh   # WSL-specific initialization (user creation)
```

## Build/Test/Sync Commands

### Primary Commands

```bash
# Apply configuration (install/update packages, sync files)
sudo decman

# First-time run (specify source file)
sudo decman --source ~/.config/arch-config/source.py

# Skip specific plugins
sudo decman --skip aur
sudo decman --skip flatpak

# Only apply file operations
sudo decman --no-hooks --only files

# Debug mode
sudo decman --debug
```

### Installation Commands

```bash
# WSL first-time setup (as root)
curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/wsl-init.sh | bash -s -- <username>

# Install decman and apply config (as regular user)
curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/install.sh | bash
```

### Testing Scripts

```bash
# Test shell scripts for syntax errors
bash -n scripts/install.sh
bash -n scripts/wsl-init.sh

# Run shellcheck if available
shellcheck scripts/*.sh

# Validate Python syntax
python -c "import py_compile; py_compile.compile('source.py', doraise=True)"
```

## Code Style Guidelines

### Shell Scripts

**Shebang & Options**:
- Always use `#!/bin/bash` (not `#!/bin/sh`)
- Start with `set -euo pipefail` for safety

**Error Handling**:
- Check command success with `if ! command; then`
- Validate user input before proceeding
- Provide clear error messages in Chinese (matching project language)
- Exit with non-zero status on errors

**Variables**:
- Use `UPPERCASE` for constants and environment variables
- Use `lowercase` for local variables
- Always quote variables: `"$VAR"` not `$VAR`

**Conditionals**:
- Prefer `[[ ]]` over `[ ]` for tests
- Use `&> /dev/null` for suppressing output
- Check command existence: `if command -v cmd &> /dev/null; then`

**User Feedback**:
- Use `echo "==> Action..."` for major steps
- Use Chinese for user-facing messages
- Show clear success indicators: `✓`

**Example Pattern**:
```bash
#!/bin/bash
set -euo pipefail

USERNAME="${1:-}"
if [ -z "$USERNAME" ]; then
    echo "用法: script.sh <参数>"
    exit 1
fi

echo "==> 执行操作..."
if ! some_command; then
    echo "错误：操作失败"
    exit 1
fi

echo "✓ 完成！"
```

### Python Configuration (source.py)

**Structure**:
- Use section dividers (`# ── Section ──`) to separate logical groups
- Group packages by purpose (基础工具, 开发工具, Zsh)
- Keep packages in sets (`|=` syntax)
- Use `os.environ.get("SUDO_USER")` for dynamic username

**Example Pattern**:
```python
import os
import decman
from decman import File

USERNAME = os.environ.get("SUDO_USER", "imbytecat")
HOME = f"/home/{USERNAME}"

decman.pacman.packages |= {"git", "neovim", "zsh"}
decman.aur.packages |= {"decman", "bun"}

decman.files["/etc/pacman.d/mirrorlist"] = File(
    source_file="./files/etc/pacman.d/mirrorlist",
)

decman.files[f"{HOME}/.zshrc"] = File(
    source_file="./dotfiles/.zshrc",
    owner=USERNAME,
)
```

### Git Workflow

**Commit Messages**:
- Follow commitlint conventional commits format
- Use Chinese for commit messages (matching project language)
- Format: `<type>(<scope>): <subject>`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- Examples:
  - `feat(source): 添加开发工具包`
  - `fix(scripts): 更新安装脚本`
  - `docs: 更新 README 说明`
  - `chore(files): 更新镜像源列表`

**Branching**:
- Main branch: `main`
- Work directly on main for personal config repos

## Important Notes for Agents

1. **decman is the source of truth**: Don't manually install packages. Add them to `source.py` and run `sudo decman`.

2. **Pacman vs AUR**: Packages must be correctly categorized into `decman.pacman.packages` (official repos) and `decman.aur.packages` (AUR).

3. **System files**: Files in `files/` are copied (not symlinked) to system locations by decman. Use `File(source_file=..., permissions=...)` with correct permissions.

4. **Dotfiles**: Files in `dotfiles/` are copied to user home by decman. Use `File(source_file=..., owner=USERNAME)`.

5. **No dry-run**: decman does not have a `--dry-run` option. Review changes in `source.py` before running `sudo decman`.

6. **Runs as root**: `sudo decman` executes `source.py` as root. `SUDO_USER` contains the original username.

7. **Language**: User-facing messages and documentation are in Chinese. Keep this consistent.

8. **Safety first**: Scripts use `set -euo pipefail` and validate inputs.

9. **Idempotency**: Scripts should be safe to run multiple times.

10. **Bootstrap flow**: `scripts/install.sh` handles one-time setup (yay, decman, locale-gen, chsh). After that, `sudo decman` handles ongoing management.

## Common Tasks

**Add a new package**:
- Determine if it's pacman or AUR
- Add to the appropriate set in `source.py`
- Run `sudo decman`

**Add a new system file**:
- Place the file in `files/` matching target path structure (e.g., `files/etc/foo.conf` → `/etc/foo.conf`)
- Add `decman.files["/etc/foo.conf"] = File(source_file="./files/etc/foo.conf")` to `source.py`
- Run `sudo decman`

**Add a new dotfile**:
- Place the file in `dotfiles/`
- Add `decman.files[f"{HOME}/.config/foo"] = File(source_file="./dotfiles/foo", owner=USERNAME)` to `source.py`
- Run `sudo decman`

**Update an existing configuration file**:
- Edit the source file in `files/` or `dotfiles/`
- Run `sudo decman`
