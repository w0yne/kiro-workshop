#!/bin/bash
set -e

echo "=== Installing Base and Additional Packages ==="

# Update package list
sudo apt update

# Install base packages and additional tools in one go
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    software-properties-common \
    build-essential \
    curl \
    unzip \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    telnet \
    jq \
    strace \
    tree \
    gcc \
    gettext \
    bash-completion

# Set environment variables
echo "Setting up environment variables..."
if ! grep -q "LANG=en_US.utf-8" /etc/environment; then
    echo "LANG=en_US.utf-8" | sudo tee -a /etc/environment
fi

if ! grep -q "LC_ALL=en_US.UTF-8" /etc/environment; then
    echo "LC_ALL=en_US.UTF-8" | sudo tee -a /etc/environment
fi

# Add basic environment variables to bashrc (AWS-specific ones moved to AWS CLI script)
if ! grep -q "export NEXT_TELEMETRY_DISABLED=1" /home/ubuntu/.bashrc; then
    echo "export NEXT_TELEMETRY_DISABLED=1" >> /home/ubuntu/.bashrc
    echo 'export PS1="\u:\w \$ "' >> /home/ubuntu/.bashrc
    echo 'PATH=$PATH:/usr/local/bin' >> /home/ubuntu/.bashrc
    echo 'export PATH' >> /home/ubuntu/.bashrc
fi

echo "Base and additional packages installed successfully"