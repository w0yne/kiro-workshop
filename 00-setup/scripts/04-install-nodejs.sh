#!/bin/bash
set -e

echo "=== Installing Node.js 24 ==="

# Install Node.js using NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo DEBIAN_FRONTEND=noninteractive apt install -y nodejs

# Update npm to latest version (matching template)
sudo npm install -g npm

# Install global packages
sudo npm install -g aws-cdk

echo "Node.js installed successfully"
node --version
npm --version
cdk --version