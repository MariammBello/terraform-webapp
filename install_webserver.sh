#!/bin/bash
set -e

# Initial setup - only runs once during instance creation
sudo apt update -y
sudo apt install -y nginx unzip curl

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -f awscliv2.zip
rm -rf aws/

# Create web directory and set permissions
sudo mkdir -p /var/www/html
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Initial file download
cd /var/www/html
aws s3 cp "s3://${bucket_name}/${html_key}" index.html
aws s3 cp "s3://${bucket_name}/${css_key}" style.css
aws s3 cp "s3://${bucket_name}/${js_key}" script.js

# Start nginx
sudo systemctl enable nginx
sudo systemctl start nginx