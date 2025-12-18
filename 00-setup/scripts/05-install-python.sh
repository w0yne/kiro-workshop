#!/bin/bash
set -e

echo "=== Installing Python and packages ==="

# Install Python packages (Ubuntu 24.04 comes with Python 3.12)
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    python3-pip \
    python3.12-venv \
    python3-boto3 \
    python3-pytest

# Create alias for python (matching template)
echo 'alias python="python3.12"' >> ~/.bashrc
echo 'alias python="python3.12"' >> /home/ubuntu/.bashrc

# Create system-wide python symlink
sudo ln -sf /usr/bin/python3.12 /usr/local/bin/python

# Install Python packages via pip (Ubuntu 24.04 compatibility)
pip3 install --break-system-packages --force-reinstall --no-deps aws-lambda-powertools
pip3 install --break-system-packages --force-reinstall --no-deps boto3  
pip3 install --break-system-packages --force-reinstall --no-deps numpy

echo "Python installed successfully"
python3 --version
pip3 --version