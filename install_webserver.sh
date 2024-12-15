#!/bin/bash
set -e

# Install required packages
sudo apt update -y
sudo apt install -y nginx unzip curl

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Create web directory
sudo mkdir -p /var/www/html
cd /var/www/html

# Function for downloading files with error handling
download_file() {
    local key=$1
    local output=$2
    
    echo "Downloading $key to $output..."
    if ! aws s3 cp "s3://${bucket_name}/$key" "$output"; then
        echo "Error downloading $key from S3"
        exit 1
    fi
}

# Download static files
download_file "${html_key}" "index.html"
download_file "${css_key}" "style.css"
download_file "${js_key}" "script.js"

# Set permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Start and enable nginx
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl restart nginx