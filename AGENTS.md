# AGENTS.md - Arch Linux Configuration Repository

## Project Overview

This is a declarative Arch Linux configuration repository managed by `dcli` (Declarative CLI for Arch). The project uses YAML-based configuration files to manage packages, modules, and system files across different hosts.

**Primary Tool**: `dcli` - Declarative package and configuration manager for Arch Linux
**Target Environment**: Arch Linux (primarily WSL, but supports bare metal)
**Language**: Shell scripts (Bash), YAML configuration files

## Repository Structure

```
.
├── config.yaml           # Main config (specifies active host)
├── hosts/                # Host-specific configurations
│   └── wsl.yaml         # WSL host config (enabled modules, AUR helper)
├── modules/             # Modular package definitions
│   ├── base.yaml        # Core utilities (git, neovim, ripgrep, etc.)
│   ├── dev-tools.yaml   # Development tools (nodejs, bun, mise)
│   └── zsh/             # Zsh module with dotfiles
│       ├── module.yaml
│       └── packages.yaml
├── files/               # System configuration files to sync
│   └── etc/            # Files that go to /etc
├── scripts/             # Installation and setup scripts
│   ├── install.sh      # Main installation script
│   └── wsl-init.sh     # WSL-specific initialization
└── state/              # dcli state directory (auto-generated)
```

## Build/Test/Sync Commands

### Primary Commands

```bash
# Apply configuration (install/update packages, sync files)
dcli sync

# Check what would change without applying
dcli sync --dry-run

# Update configuration from git
cd ~/.config/arch-config && git pull && dcli sync
```

### Installation Commands

```bash
# WSL first-time setup (as root)
curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/wsl-init.sh | bash -s -- <username>

# Install dcli and clone config (as regular user)
curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/install.sh | bash

# Then sync configuration
dcli sync
```

### Testing Scripts

```bash
# Test shell scripts for syntax errors
bash -n scripts/install.sh
bash -n scripts/wsl-init.sh

# Run shellcheck if available
shellcheck scripts/*.sh
```

### Package Management

```bash
# Install packages manually (if needed)
sudo pacman -S <package>          # Official repos
yay -S <package>                  # AUR packages

# Update system
sudo pacman -Syu
```

## Code Style Guidelines

### Shell Scripts

**Shebang & Options**:
- Always use `#!/bin/bash` (not `#!/bin/sh`)
- Start with `set -euo pipefail` for safety
- Exit on errors, undefined variables, and pipe failures

**Error Handling**:
- Check command success with `if ! command; then`
- Validate user input before proceeding
- Provide clear error messages in Chinese (matching project language)
- Exit with non-zero status on errors

**Variables**:
- Use `UPPERCASE` for constants and environment variables
- Use `lowercase` for local variables
- Always quote variables: `"$VAR"` not `$VAR`
- Use `${VAR}` for clarity when needed

**Conditionals**:
- Prefer `[[ ]]` over `[ ]` for tests
- Use `&> /dev/null` for suppressing output
- Check file existence: `if [ -e "$FILE" ]; then`
- Check command existence: `if command -v cmd &> /dev/null; then`

**User Feedback**:
- Use `echo "==> Action..."` for major steps
- Use Chinese for user-facing messages
- Show clear success indicators: `✓`
- Provide next steps after completion

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

### YAML Configuration Files

**Structure**:
- Use `---` document separator at the start
- Use 2-space indentation (no tabs)
- Keep files minimal and focused

**Module Files** (`modules/*.yaml`):
```yaml
---
description: 模块描述
packages:
  - package-name
  - another-package
```

**Module with Dotfiles** (`modules/*/module.yaml`):
```yaml
---
description: 模块描述
dotfiles:
  - source: dotfiles/.config/file
    target: ~/.config/file
```

**Host Files** (`hosts/*.yaml`):
```yaml
host: hostname
aur_helper: yay
auto_prune: true

enabled_modules:
  - base
  - module-name

system_backups:
  enabled: false
```

**Main Config** (`config.yaml`):
```yaml
host: hostname
```

**Naming Conventions**:
- Use lowercase with hyphens for module names: `dev-tools`, not `DevTools`
- Use descriptive names in Chinese for descriptions
- Keep package lists alphabetically sorted

### File Organization

**Adding New Modules**:
1. Create `modules/module-name.yaml` with package list
2. Add module to `hosts/*.yaml` under `enabled_modules`
3. Run `dcli sync` to apply

**Adding Dotfiles**:
1. Create `modules/module-name/dotfiles/` directory
2. Add dotfile mapping in `modules/module-name/module.yaml`
3. Place actual dotfiles in the dotfiles subdirectory

**Adding System Files**:
1. Place files in `files/` matching target path structure
2. Example: `files/etc/pacman.d/mirrorlist` → `/etc/pacman.d/mirrorlist`
3. Scripts handle copying with proper permissions

### Git Workflow

**Commit Messages**:
- Follow commitlint conventional commits format
- Use Chinese for commit messages (matching project language)
- Format: `<type>(<scope>): <subject>`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- Examples: 
  - `feat(modules): 添加开发工具模块`
  - `fix(scripts): 更新 WSL 初始化脚本`
  - `docs: 更新 README 说明`
  - `chore(deps): 更新包列表`

**Branching**:
- Main branch: `main`
- Work directly on main for personal config repos
- Test changes with `dcli sync --dry-run` before committing

## Important Notes for Agents

1. **dcli is the source of truth**: Don't manually install packages. Add them to module YAML files and run `dcli sync`.

2. **Host-specific configuration**: The active host is defined in `config.yaml`. Different hosts can have different enabled modules.

3. **AUR packages**: This repo uses `yay` as the AUR helper. Both official and AUR packages go in the same `packages:` list.

4. **WSL-specific**: The default configuration targets WSL. For bare metal, create a new host file and switch `config.yaml`.

5. **File syncing**: Files in `files/` are copied to system locations. Maintain the directory structure matching the target paths.

6. **No tests**: This is a configuration repository. Testing is done via `dcli sync --dry-run` and manual verification.

7. **Language**: User-facing messages and documentation are in Chinese. Keep this consistent.

8. **Safety first**: Scripts use `set -euo pipefail` and validate inputs. Maintain this pattern.

9. **Idempotency**: Scripts should be safe to run multiple times. Check if resources exist before creating.

10. **State management**: The `state/` directory is managed by dcli. Don't modify it manually.

## Common Tasks

**Add a new package**:
- Edit appropriate module YAML file
- Add package name to `packages:` list
- Run `dcli sync`

**Create a new module**:
- Create `modules/new-module.yaml`
- Add packages and optional dotfiles config
- Enable in `hosts/*.yaml`
- Run `dcli sync`

**Update system configuration file**:
- Edit file in `files/` directory
- Run install script or manually copy to system location
- Restart affected services if needed

**Switch to a different host**:
- Create `hosts/new-host.yaml` if needed
- Edit `config.yaml` to change `host:` value
- Run `dcli sync`
