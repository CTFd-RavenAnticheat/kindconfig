#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting Ultimate Environment Setup for Debian Bookworm..."

# 1. DNS Resilience Fix (Azure/Debian specific)
echo "🌐 Configuring DNS (8.8.8.8) for reliability..."
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf >/dev/null

# 2. Update and install basic dependencies
echo "📦 Installing base packages..."
sudo apt update && sudo apt install -y \
  curl gpg software-properties-common apt-transport-https \
  ca-certificates netcat-openbsd neovim git wget jq lsb-release

# 3. Install Docker & Docker Compose
echo "🐳 Installing Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. Install Helm (via Official Script to bypass CDN issues)
echo "⚓ Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

# 5. Add Repos for Azure and GitHub CLI
echo "🐙 Adding Azure and GitHub CLI Repos..."
# Azure CLI
curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/azure-cli.list

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list

sudo apt update && sudo apt install -y azure-cli gh

# 6. Install Kubectl, Kind, and K9s
echo "🔧 Installing K8s Tools (Kubectl, Kind, K9s)..."
ARCH=$([ "$(uname -m)" = "x86_64" ] && echo "amd64" || echo "arm64")

# Kubectl
K8S_VER=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VER}/bin/linux/${ARCH}/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-${ARCH}
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind

# K9s
K9S_VER=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | jq -r .tag_name)
curl -Lo k9s.tar.gz "https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Linux_${ARCH}.tar.gz"
tar -xzf k9s.tar.gz k9s
sudo install -o root -g root -m 0755 k9s /usr/local/bin/k9s
rm kubectl kind k9s k9s.tar.gz

# 7. Install K3s (Server mode)
echo "🪄 Installing K3s..."
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --disable traefik

# 8. Final Configuration (Permissions & Aliases)
sudo usermod -aG docker $USER
grep -qxF "alias k='kubectl'" ~/.bashrc || echo "alias k='kubectl'" >>~/.bashrc
grep -qxF "alias k9s='k9s --readonly'" ~/.bashrc || echo "alias k9s='k9s --readonly'" >>~/.bashrc

echo "------------------------------------------------"
echo "✅ ALL DONE!"
echo "👉 Run: 'newgrp docker' to apply group changes."
echo "👉 Run: 'source ~/.bashrc' to enable the 'k' alias."
echo "👉 Verify K9s by typing: k9s"
echo "------------------------------------------------"
