# devbox

Ansible playbook for provisioning a Fedora Asahi Remix (aarch64/Apple Silicon) development laptop from scratch.

One command takes a fresh install to a fully configured dev environment.

## What's included

| Role | What it sets up |
|------|----------------|
| **base** | Build tools, RPM Fusion repos, system update |
| **shell** | Zsh + Oh My Zsh + plugins (fzf-tab, autosuggestions, syntax highlighting, history search, and more) |
| **terminal** | Ghostty terminal emulator via COPR |
| **git** | Git, GitHub CLI, `.gitconfig`, SSH ed25519 key generation |
| **editors** | Neovim + VS Code (Flatpak) |
| **languages** | Node.js (fnm), Rust (rustup), Go, Python (uv/uvx) |
| **containers** | Docker CE + Compose + Buildx |
| **infra** | OpenTofu, kubectl, Helm, k9s |
| **cloud_cli** | AWS CLI v2, Google Cloud CLI, Azure CLI |
| **devtools** | tmux, fzf, ripgrep, bat, eza, zoxide, btop, jq, yq, httpie, lazygit |
| **ai_tools** | Claude Code, OpenCode |
| **flatpak** | VS Code, ZapZap (WhatsApp) |

## Quick start

```bash
# 1. Clone the repo
git clone git@github.com:mushhzz/devbox.git ~/devbox
cd ~/devbox

# 2. Copy and edit your personal config
cp group_vars/all.yml.example group_vars/all.yml
nano group_vars/all.yml  # Set your git name, email, username

# 3. Run it
./bootstrap.sh
```

The bootstrap script installs Ansible if needed, pulls required collections, and runs the playbook. You'll be prompted for your sudo password.

## Selective runs

Run specific roles using tags:

```bash
./bootstrap.sh --tags "shell,editors"
./bootstrap.sh --tags "languages,devtools"
./bootstrap.sh --tags "containers,infra,cloud_cli"
```

Dry run to see what would change:

```bash
./bootstrap.sh --check
```

## Configuration

All user-customizable variables live in `group_vars/all.yml` (gitignored). See `group_vars/all.yml.example` for the full list:

- **git_user_name / git_user_email** — Git identity + SSH key comment
- **target_user** — Your Linux username
- **omz_plugins** — Oh My Zsh plugin list
- **install_docker / install_aws_cli / install_gcloud / install_azure_cli** — Toggle features on/off
- **install_claude_code / install_opencode** — AI coding tools

## Requirements

- Fedora 43+ (tested on Asahi Remix, aarch64)
- Internet connection
- sudo access

## Post-install

Log out and back in after running for shell (zsh) and group (docker) changes to take effect.
