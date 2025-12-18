#!/bin/bash
set -e

echo "=== Installing AWS CLI ==="

# Download and install AWS CLI
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install --update

# Clean up
rm -rf /tmp/aws /tmp/awscliv2.zip

# Add AWS CLI completion if not exists
if ! grep -q 'complete -C "/usr/local/bin/aws_completer" aws' ~/.bashrc; then
    echo 'complete -C "/usr/local/bin/aws_completer" aws' >> ~/.bashrc
fi

# Add AWS environment variables to bashrc
if ! grep -q "export AWS_REGION=" /home/ubuntu/.bashrc; then
    # Get AWS region using IMDSv2 (with fallback to us-east-1)
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || echo "")
    if [[ -n "$TOKEN" ]]; then
        AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "us-east-1")
    else
        AWS_REGION="us-east-1"
    fi
    
    echo "export AWS_REGION=$AWS_REGION" >> /home/ubuntu/.bashrc
    echo "export AWS_DEFAULT_REGION=$AWS_REGION" >> /home/ubuntu/.bashrc
    echo "export AWS_ACCOUNTID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'UNKNOWN')" >> /home/ubuntu/.bashrc
fi

echo "AWS CLI installed and configured successfully"
aws --version