#!/bin/bash
set -e

echo "=== Installing VS Code Server and Configuring Nginx ==="

# Check if code-server is already installed
if command -v code-server >/dev/null 2>&1; then
    echo "VS Code Server already installed: $(code-server --version | head -1)"
    SKIP_VSCODE_INSTALL=true
else
    echo "VS Code Server not found, installing..."
    SKIP_VSCODE_INSTALL=false
fi

if [[ "$SKIP_VSCODE_INSTALL" != "true" ]]; then
    # Install code-server
    export HOME=/home/ubuntu
    curl -fsSL https://code-server.dev/install.sh | sh
fi

# Install and configure Nginx
sudo DEBIAN_FRONTEND=noninteractive apt install -y nginx

# Configure code-server
sudo -u ubuntu mkdir -p /home/ubuntu/.config/code-server
sudo -u ubuntu mkdir -p /home/ubuntu/.local/share/code-server/User/

# Create code-server config
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
# Install argon2 for password hashing
sudo DEBIAN_FRONTEND=noninteractive apt install -y argon2
# Generate salt and hash password
SALT=$(openssl rand -hex 16)
HASHED_PASSWORD=$(echo -n "$ACCOUNT_ID" | argon2 "$SALT" -e)
sudo tee /home/ubuntu/.config/code-server/config.yaml <<EOF
cert: false
auth: password
hashed-password: "$HASHED_PASSWORD"
EOF

# Create VS Code settings
sudo tee /home/ubuntu/.local/share/code-server/User/settings.json <<EOF
{
  "extensions.autoUpdate": false,
  "extensions.autoCheckUpdates": false,
  "terminal.integrated.cwd": "/home/ubuntu/workspace/kiro-workshop",
  "telemetry.telemetryLevel": "off",
  "security.workspace.trust.startupPrompt": "never",
  "security.workspace.trust.enabled": false,
  "security.workspace.trust.banner": "never",
  "security.workspace.trust.emptyWindow": false,
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.formatOnSave": true
  },
  "workbench.colorTheme": "Default Dark Modern",
  "workbench.startupEditor": "none",
  "workbench.welcomePage.walkthroughs.openOnInstall": false,
  "chat.agent.enabled": false,
  "chat.disableAIFeatures": true
}
EOF

# Get CloudFront domain from environment variable or parameter
CLOUDFRONT_DOMAIN=${CLOUDFRONT_DOMAIN:-${1:-"localhost"}}

# Create static files directory for frontend
sudo mkdir -p /var/www/html/proxy/5173

# Create Nginx configuration for code-server
sudo tee /etc/nginx/sites-available/code-server <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $CLOUDFRONT_DOMAIN;
    
    # Prohibit access to code-server through /proxy/8080
    location ^~ /proxy/8080/ {
        return 403;
    }

    # API proxy to backend (highest priority for API)
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Disable buffering for SSE support
        proxy_buffering off;
        proxy_cache off;
        
        # SSE support
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
    }

    # Frontend static files (highest priority for /proxy/5173)
    location ^~ /proxy/5173/ {
        alias /var/www/html/proxy/5173/;
        try_files \$uri \$uri/ /proxy/5173/index.html;
        
        # Prevent caching issues during development
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # Dynamic proxy for any port with path (exclude 5173)
    location ~ ^/proxy/(?!5173)(\d+)/(.*)$ {
        proxy_pass http://127.0.0.1:\$1/\$2;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Fallback for root proxy paths (exclude 5173)
    location ~ ^/proxy/(?!5173)(\d+)/?$ {
        proxy_pass http://127.0.0.1:\$1/;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # code-server (default location)
    location / {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/code-server

# Remove default site if it exists
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Enable and start services
sudo systemctl enable --now code-server@ubuntu
sudo systemctl restart nginx

# Install VS Code extensions
sudo -u ubuntu --login code-server --install-extension synedra.auto-run-command --force

# Create and set up home folder (matching template HomeFolder parameter)
sudo mkdir -p /home/ubuntu/workspace/kiro-workshop
sudo chown ubuntu:ubuntu /home/ubuntu/workspace/kiro-workshop

# Set proper ownership
sudo chown ubuntu:ubuntu /home/ubuntu -R

# Restart code-server
sudo systemctl restart code-server@ubuntu

echo "VS Code Server and Nginx configured successfully"