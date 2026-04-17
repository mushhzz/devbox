#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Dev Laptop Bootstrap ==="
echo ""

# Step 1: Install Ansible
if ! command -v ansible-playbook &>/dev/null; then
    echo "[1/3] Installing Ansible..."
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if ! command -v brew &>/dev/null; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install ansible
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y ansible
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y ansible
    else
        echo "Error: unsupported package manager. Install ansible manually."
        exit 1
    fi
else
    echo "[1/3] Ansible already installed ($(ansible --version | head -1))"
fi

# Step 2: Install required collections
echo "[2/3] Installing Ansible collections..."
ansible-galaxy collection install community.general community.crypto --force-with-deps 2>/dev/null

# Step 3: Run the playbook
echo "[3/3] Running playbook..."
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo ""
    echo "You will be prompted for your sudo password."
    echo ""
fi

cd "$SCRIPT_DIR"
if [[ "$(uname -s)" == "Darwin" ]]; then
    ansible-playbook playbook.yml "$@"
else
    ansible-playbook playbook.yml --ask-become-pass "$@"
fi

echo ""
echo "=== Done! Log out and back in for shell + group changes to take effect. ==="
