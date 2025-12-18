#!/bin/bash
set -e

echo "=== Installing and Configuring Git ==="

# Add Git PPA for latest version
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y git

# Configure Git for workshop user
sudo -u ubuntu git config --global user.email "participant@workshops.aws"
sudo -u ubuntu git config --global user.name "Workshop Participant"
sudo -u ubuntu git config --global init.defaultBranch "main"

echo "Git installed and configured successfully"
git --version