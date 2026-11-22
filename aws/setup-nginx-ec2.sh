#!/usr/bin/env bash
# ==============================================================================
# Production Nginx Reverse Proxy Setup for CampusGigs on AWS EC2
# Maps Port 80 (Standard HTTP) -> Port 5000 (Node.js Express App)
# ==============================================================================
set -euo pipefail

echo "Installing Nginx..."
sudo apt-get update -y
sudo apt-get install -y nginx

echo "Configuring Nginx Reverse Proxy for CampusGigs..."
sudo tee /etc/nginx/sites-available/campusgigs > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;
    client_max_body_size 10M;

    # Compression for high performance
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml image/svg+xml;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/campusgigs /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "✓ Nginx is active! CampusGigs is now accessible directly at http://<EC2-PUBLIC-IP> on port 80."
