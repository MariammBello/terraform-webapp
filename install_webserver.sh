#!/bin/bash
sudo apt update -y
sudo apt install nginx certbot python3-certbot-nginx -y

# Create web content
cat << 'EOF' > /var/www/html/index.html
${html_content}
EOF

cat << 'EOF' > /var/www/html/style.css
${css_content}
EOF

cat << 'EOF' > /var/www/html/script.js
${js_content}
EOF

# Set proper permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

sudo systemctl restart nginx