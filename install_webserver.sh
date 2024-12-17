#!/bin/bash
set -e

# Check and install packages if not present
check_install() {
    if ! command -v $1 &> /dev/null; then
        echo "Installing $1..."
        sudo apt update -y
        sudo apt install -y $1
    else
        echo "$1 is already installed"
    fi
}

# Install required packages
check_install nginx
check_install certbot
check_install python3-certbot-nginx

# Install AWS CLI v2 if not present
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -f awscliv2.zip
    rm -rf aws/
else
    echo "AWS CLI is already installed"
fi

# Create web directory if it doesn't exist
if [ ! -d "/var/www/html" ]; then
    sudo mkdir -p /var/www/html
fi

# Configure Nginx initially with a basic configuration
echo "Configuring Nginx..."
sudo aws s3 cp "s3://${bucket_name}/${nginx_config_key}" /etc/nginx/sites-available/default
# Replace the placeholder with the actual domain name
sudo sed -i "s/server_name _;/server_name ${domain_name};/g" /etc/nginx/sites-available/default

# Setup SSL
if [ -n "${domain_name}" ]; then
    echo "Setting up SSL for ${domain_name}..."
    # Stop nginx temporarily to free up port 80
    sudo systemctl stop nginx
    # Run certbot in standalone mode
    sudo certbot certonly --standalone -d ${domain_name} --non-interactive --agree-tos --email admin@${domain_name}
    # Start nginx again
    sudo systemctl start nginx
    
    # Update SSL certificate paths in nginx config
    sudo sed -i "s|/etc/letsencrypt/live/default/|/etc/letsencrypt/live/${domain_name}/|g" /etc/nginx/sites-available/default
else
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    if [ ! -d "/etc/letsencrypt/live/$PUBLIC_IP.nip.io" ]; then
        echo "Setting up SSL for $PUBLIC_IP.nip.io..."
        sudo certbot --nginx --register-unsafely-without-email --agree-tos -d $PUBLIC_IP.nip.io --non-interactive
    else
        echo "SSL certificate already exists for $PUBLIC_IP.nip.io"
    fi
fi

# Setup cert renewal if not already configured
if [ ! -f "/etc/cron.d/certbot-renew" ]; then
    echo "Setting up certificate renewal..."
    echo "0 12 * * * /usr/bin/certbot renew --quiet --post-hook '/bin/systemctl reload nginx'" | sudo tee /etc/cron.d/certbot-renew
    sudo chmod 600 /etc/cron.d/certbot-renew
fi

# Update static files and permissions
echo "Updating static files..."
sudo aws s3 cp "s3://${bucket_name}/${html_key}" /var/www/html/index.html
sudo aws s3 cp "s3://${bucket_name}/${css_key}" /var/www/html/style.css
sudo aws s3 cp "s3://${bucket_name}/${js_key}" /var/www/html/script.js

sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Ensure Nginx is running
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "Setup completed successfully!"