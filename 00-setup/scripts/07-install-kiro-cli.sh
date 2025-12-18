#!/bin/bash
set -e

echo "=== Installing Kiro CLI ==="

# Check if kiro-cli is already installed
if command -v kiro-cli >/dev/null 2>&1; then
    echo "Kiro CLI already installed: $(kiro-cli --version)"
    SKIP_KIRO_INSTALL=true
else
    echo "Kiro CLI not found, installing..."
    SKIP_KIRO_INSTALL=false
fi

if [[ "$SKIP_KIRO_INSTALL" != "true" ]]; then
    # Install Kiro CLI
    curl -fsSL https://cli.kiro.dev/install | bash
fi

# Add Kiro CLI to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/ubuntu/.bashrc

# Source the updated PATH for current session
export PATH="$HOME/.local/bin:$PATH"

echo "Kiro CLI installed successfully"