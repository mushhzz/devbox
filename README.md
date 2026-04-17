# devbox

Ansible playbook for provisioning a development laptop from scratch. Supports **Fedora** (including Asahi Remix on Apple Silicon), **Ubuntu**, and **macOS**.

One command takes a fresh install to a fully configured dev environment.

## What's included

| Role | What it sets up | macOS notes |
|------|----------------|-------------|
| **base** | Build tools, repos, system update | Homebrew + Xcode CLT |
| **shell** | Zsh + Oh My Zsh + plugins (fzf-tab, autosuggestions, syntax highlighting, history search, and more) | Cross-platform |
| **terminal** | Ghostty terminal emulator | Installed via Homebrew cask |
| **git** | Git, GitHub CLI, `.gitconfig`, SSH ed25519 key generation, gh credential helper | Cross-platform |
| **editors** | Neovim + VS Code (+ JetBrains Toolbox opt-in) | VS Code and Toolbox via Homebrew cask on macOS |
| **languages** | Node.js (fnm), Rust (rustup), Go, Python (uv/uvx) | Go via Homebrew, others cross-platform |
| **containers** | Docker CE + Compose + Buildx | colima + Docker CLI on macOS |
| **infra** | OpenTofu, kubectl, Helm, k9s, kind, Terragrunt, terraform→tofu symlink | All via Homebrew on macOS |
| **cloud_cli** | AWS CLI v2, Google Cloud CLI, Azure CLI | AWS via .pkg, gcloud/azure via Homebrew |
| **devtools** | tmux, fzf, ripgrep, bat, eza, zoxide, btop, jq, yq, httpie, lazygit (+ ngrok opt-in) | All via Homebrew on macOS |
| **ai_tools** | Claude Code, OpenCode | Cross-platform |
| **sec_tools** | checkov, detect-secrets, policy-sentry, cloudsplaining (opt-in) | Installed via uv tool |
| **flatpak** | VS Code, Obsidian, DBeaver | Homebrew casks on macOS |
| **keyboard** | keyd (Linux) / Karabiner-Elements (macOS) | Different tools, same goal: swap Fn/Ctrl |
| **intune** | Microsoft Intune + Edge | Company Portal via Homebrew cask on macOS |

## Supported platforms

| Platform | Architectures | Status |
|----------|--------------|--------|
| Fedora 43+ | aarch64, x86_64 | Tested on Asahi Remix |
| Ubuntu 24.04+ | aarch64, x86_64 | Supported |
| macOS (Sequoia+) | Apple Silicon, Intel | Supported |

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

The bootstrap script installs Ansible if needed, pulls required collections, and runs the playbook. On Linux you'll be prompted for your sudo password. On macOS, Homebrew may prompt for your password during installations.

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
- **target_user** — Your username
- **target_user_home** — Auto-detected: `/Users/<name>` on macOS, `/home/<name>` on Linux
- **omz_plugins** — Oh My Zsh plugin list
- **install_docker / install_aws_cli / install_gcloud / install_azure_cli** — Toggle features on/off
- **install_claude_code / install_opencode** — AI coding tools
- **install_ngrok** — ngrok tunnel tool (default: false)
- **install_sec_tools** — Security tools: checkov, detect-secrets, policy-sentry, cloudsplaining (default: false)
- **install_jetbrains_toolbox** — JetBrains Toolbox + IDE manager (default: false)

## Post-install: authentication checklist

The playbook installs all tools but **does not store authentication secrets** (by design). Complete these steps after provisioning:

### Required (run these interactively)

```bash
# GitHub CLI — enables git push/pull with GitHub
gh auth login

# SSH key — add to GitHub
cat ~/.ssh/id_ed25519.pub
# → paste at https://github.com/settings/keys

# Claude Code
claude login

# Docker (macOS) — start the colima VM
colima start

# Kubernetes — create a kind cluster if needed
kind create cluster --name dev
```

### Cloud CLI auth (run what you need)

```bash
# Google Cloud
gcloud auth login
gcloud auth application-default login

# AWS — configure credentials or SSO
aws configure
# or for SSO:
aws configure sso

# Azure
az login
```

### Optional

```bash
# ngrok (if install_ngrok: true)
ngrok config add-authtoken <YOUR_TOKEN>

# OpenCode — set API key via environment variable or config
```

### What gets configured automatically

- **Git credential helper** — `gh auth setup-git` is templated into `.gitconfig` so git push/pull uses GitHub CLI auth
- **SSH key** — `id_ed25519` is generated; the public key is printed for you to add to GitHub
- **zsh** — set as default shell; Oh My Zsh + plugins deployed
- **Docker group** — your user is added to the `docker` group (Linux)

## macOS-specific notes

- **Homebrew** is installed automatically if not present
- **Xcode Command Line Tools** are installed automatically
- **Docker** uses **colima** (lightweight Linux VM) instead of Docker Desktop — run `colima start` before using Docker
- **Keyboard remapping** uses Karabiner-Elements instead of keyd (same Fn/Ctrl swap)
- **Flatpak** is not available on macOS; GUI apps use Homebrew casks instead
- Paths use `/Users/<name>` instead of `/home/<name>` automatically

## Post-install

Log out and back in after running for shell (zsh) and group (docker) changes to take effect.

On macOS, start colima before using Docker:
```bash
colima start
```