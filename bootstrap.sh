#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Fedora Asahi Dev Laptop Bootstrap ==="
echo ""

# Step 1: Install Ansible
if ! command -v ansible-playbook &>/dev/null; then
    echo "[1/3] Installing Ansible..."
    sudo dnf install -y ansible
else
    echo "[1/3] Ansible already installed ($(ansible --version | head -1))"
fi

# Step 2: Install required collections
echo "[2/3] Installing Ansible collections..."
ansible-galaxy collection install community.general community.crypto --force-with-deps 2>/dev/null

# Step 3: Run the playbook
echo "[3/3] Running playbook..."
echo ""
echo "You will be prompted for your sudo password."
echo ""

cd "$SCRIPT_DIR"
ansible-playbook playbook.yml --ask-become-pass "$@"

echo ""
echo "=== Done! Log out and back in for shell + group changes to take effect. ==="
