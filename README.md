# Automating Secure Web Server Deployment with Terraform: A Custom Landing Page Project.

This guide explains how to deploy a secure and automated web server on AWS using Terraform, an EC2 instance, and Nginx. Static files are served from a provisioned S3 bucket, and SSL certificates are automatically provisioned using Let's Encrypt. Installations and updates are done in a bash script that is executed from the terraform automation. 
By the end of this guide, you will have a fully configured HTTPS-enabled web server with automated deployment.
## Architecture Diagram
[View the architecture diagram on Excalidraw](https://excalidraw.com/#json=db3E_IK8fQmK5U9ztsKZb,kpV_kGpBEVZnInVypnASrw)

# Checkout the website deployed 
 - [**IP Address: http://98.85.131.86**](http://98.85.131.86)
 - [***Website secure url: https://cloud.3figirl.com***](https://cloud.3figirl.com)


![Website Preview](website_image.jpg)
               [***snapshot of website landing page***](https://cloud.3figirl.com)

# How it was built. 

What you'll need before starting, ensure you have the following:
- AWS Account: Required to create resources (EC2, S3, IAM, etc).
- Terraform Installed: Download Terraform.
- AWS CLI Installed: Install AWS CLI 
- IAM User with Terraform Permissions: A single IAM user policy grants permissions to manage EC2, S3, and IAM resources.
- AWS CLI Configuration: The IAM user's access and secret keys are configured locally to authenticate Terraform commands.
- SSH Key Pair: Create a key pair to SSH into the EC2 instance. Use ssh-keygen to generate the keys: ```ssh-keygen -t rsa -b 2048 -f mariamhostspace```. This generates private and public key for SSH.
- Replace ssh key information in terraform main.tf 
- Once all the requirements are made, and you decide to clone this repo, replace the index.html, style.css and script.js to your preffered files. 
- To Deploy the webpage please see deployment instructions at the end of the documentation.

Lets go!

# HTML Page Deployment
This is done within a terraform code (main.tf) to enable automation and reproducibility of assignment.  

### S3 Bucket Setup : 
Amazon S3 (Simple Storage Service) is a highly scalable storage solution for files, objects, and backups. Using Terraform, we can automate the creation and configuration of an S3 bucket. Let’s break down the code snippet into its components

The terraform block creates an S3 bucket with a globally unique name to storee the static frontend files - index.html, style.css, and script.js. It also Enables versioning to track file changes and Sets up lifecycle rules to delete old file versions after 1 day.

s3 Bucket Creation Block in AWS (The Terraform code can be cloned in my repository)

```yaml
resource "aws_s3_bucket" "static_files" {
  bucket        = "mariam-altschool-static-2024"
  force_destroy = true
``` 
**Key Points**

- ```resource "aws_s3_bucket"```: This is the resource block in Terraform. It tells Terraform to create an S3 bucket using the AWS provider.
- ```aws_s3_bucket```: This is the resource type. AWS S3 bucket resources are defined using this block.
- ```static_files```:This is the logical name you give to the resource in Terraform. You can reference this name elsewhere in the code.
- ```bucket = "globally unique name"```: The name of the S3 bucket must be globally unique across all AWS accounts and regions. Example: "my-static-files-1234".
- ```force_destroy = true```:Allows Terraform to delete the bucket even if it contains objects. ***Why?*** Normally, S3 buckets cannot be deleted if they contain files or objects.
When force_destroy is true, Terraform automatically deletes everything inside the bucket before deleting the bucket itself. This aids automation and reduces the need to manually remove resources

### Uploading static files as s3 objects
The aws_s3_object resource represents a single file that you want to upload to an S3 bucket. Each file will have a key (its name in the bucket), source (where it is on your system), and metadata (e.g., content type).

**Uploading Html code sample object**
```hcl
resource "aws_s3_object" "html_file" {
  bucket = aws_s3_bucket.static_files.id
  key    = "index.html"
  source = "index.html"
  content_type = "text/html"
  etag = filemd5("index.html")
}
```
- ```bucket``` This specifies the target S3 bucket where the file will be uploaded.
- ```Value: aws_s3_bucket.static_files.id```: dynamically references the ID of the S3 bucket created elsewhere in your configuration.
- ```key``` Defines the name of the file in the bucket. This name is used to access the file in the bucket (e.g., index.html will be stored as https://<bucket-name>.s3.amazonaws.com/index.html).
- ```source``` This points to the local file on your machine that you want to upload.
Example: If you’re uploading index.html, the source should be the path to index.html on your system.
- ```content_type```: This specifies the file type (MIME type) for the uploaded object. It ensures the file is interpreted correctly by browsers or applications. For example:
     - text/html → Web browsers treat it as an HTML page.
     - text/css → Interpreted as a CSS stylesheet.
     - application/javascript → Treated as a JavaScript file.
- ```etag```: Adds a hash (MD5 checksum) of the file using the filemd5() function. It ensures the file is uploaded only if its content has changed. Avoids unnecessary uploads, making deployments faster and more efficient.

# Provisioning the server

### Creating EC2 Instance and Elastic IP Configuration to host website on.
This Terraform configuration deploys an EC2 instance with necessary configurations and an Elastic IP (EIP) for consistent public access. It references other resources such as an IAM instance profile, security group, and S3 objects previously created (See source code explained at the end of doc for full details).

**1. EC2 Instance (aws_instance)**: The EC2 instance serves as the web server hosting your application. Creating this depends on a security group for access control, an IAM instance profile for permissions and the S3 objects for static files and Nginx configuration in this setup (detailed in the second more advanced part of doc)

```
resource "aws_instance" "web_server" {
  depends_on = [
    aws_iam_instance_profile.ec2_profile,
    aws_security_group.web_sg,
    aws_s3_object.nginx_config
  ]
  ami           = "ami-0e2c8caa4b6378d8c"
  instance_type = "t2.micro"              
  key_name      = aws_key_pair.deployer.key_name  // Reference the created key pair
  vpc_security_group_ids = [aws_security_group.web_sg.id]  // Direct reference
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name  // Direct reference

  user_data = base64encode(templatefile("install_webserver.sh", {
    bucket_name = aws_s3_bucket.static_files.id
    html_key    = aws_s3_object.html_file.key
    css_key     = aws_s3_object.css_file.key
    js_key      = aws_s3_object.js_file.key
    nginx_config_key = aws_s3_object.nginx_config.key
    domain_name = var.domain_name
  }))

  ``` 
```depends_on```: Ensures the instance is created only after the listed resources are available:
- IAM instance profile (ec2_profile): For permissions.
- Security group (web_sg): For network access control.
- S3 object (nginx_config): Ensures configuration is ready before instance creation.
-  **```ami```**: Specifies the Amazon Machine Image (AMI) to use for the instance. The AMI determines the operating system and base configuration for the EC2 instance.
- ```instance_type```: Specifies the size of the instance. Determines the compute, memory, and network capacity.
- ```key_name```: References the name of an existing key pair for SSH access to the instance.
- ```vpc_security_group_ids```: Associates the instance with a security group (web_sg), controlling inbound and outbound traffic.
- ```iam_instance_profile```: Links the EC2 instance to the IAM instance profile, granting it the permissions defined in the IAM role.

  ```
**2. Elastic IP (aws_eip)**: An Elastic IP provides a static public IP address for the EC2 instance. This ensures the web server's IP does not change, even if the instance is stopped and restarted.

```hcl
resource "aws_eip" "web_eip" {
  instance = aws_instance.web_server.id
  domain   = "vpc"
}
```
- ```instance```: Links the Elastic IP to the EC2 instance (web_server).
- ```domain```: Specifies the networking domain. For VPC instances, this is always "vpc".
- ```Dependencies```: The depends_on block ensures all prerequisites (IAM role, security group, S3 objects) are in place before the instance is created.
  
**3.  Security Group**
A security group acts as a virtual firewall for your EC2 instance, controlling inbound (ingress) and outbound (egress) traffic. In this case, the security group: Allows HTTP (port 80), HTTPS (port 443), and SSH (port 22) traffic and Permits all outbound traffic.

```hcl
resource "aws_security_group" "web_sg" {
  name        = "altschool-web-sg"
  description = "Allow HTTP, HTTPS and SSH traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

 ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

  }
}

```

- name: Assigns a fixed name (altschool-web-sg) to the security group, making it easier to identify in the AWS console.
- description: Explains the purpose of the security group.
- Definining rules for inbound traffic:
    - Port 22 (SSH): Allows secure remote access.
    - Port 80 (HTTP): Enables access to the web server via a browser.
    - Port 443 (HTTPS): Supports secure web traffic.
    - cidr_blocks = ["0.0.0.0/0"]: Allows traffic from any IP address. In production, you should restrict this to specific IPs for security.
egress Block

Defining rules for outbound traffic:
Allows all outbound traffic (from_port = 0, to_port = 0, protocol = "-1").

**4. Key Pair (aws_key_pair)**
A key pair is used to securely SSH into your EC2 instance. The public key is stored in AWS, while the private key is kept on your machine for authentication.

key_name

Assigns a name to the key pair (mariamhostspace). This name will be referenced in your EC2 instance configuration.
public_key

Specifies the path to your public key file (mariamhostspace.pub).
Ensure File Exists: The public key must already exist in your project directory. Use ssh-keygen to generate it if you don’t have one.
How to Generate a Key Pair
Open your terminal or command prompt.

Run the following command to generate a new SSH key pair:

```bash
ssh-keygen -t rsa -b 2048 -f mariamhostspace
```
This will create:

A private key: mariamhostspace.pem
A public key: mariamhostspace.pub
Ensure the .pem file has the correct permissions:

```bash
chmod 400 mariamhostspace.pem
```
# Networking & Web Server Setup
### Done using a BASH Script - Installation and Updates
This script automates the setup of an Nginx-based web server, including installing necessary packages, setting up SSL certificates, configuring Nginx, and deploying static files from an S3 bucket.

### Script Setup
```bash
#!/bin/bash
set -e
```
- ```#!/bin/bash```: Specifies that this script will run in the Bash shell.
- ```set -e```: Causes the script to exit immediately if any command fails, ensuring that errors are handled without proceeding to subsequent steps.


### Function to Check and Install Packages
```bash
check_install() {
    if ! command -v $1 &> /dev/null; then
        echo "Installing $1..."
        sudo apt update -y
        sudo apt install -y $1
    else
        echo "$1 is already installed"
    fi
}
```

- ```check_install()```: A reusable function to check if a package is installed and install it if it’s not.
- ```command -v $1```: Checks if the given command exists in the system ($1 is the argument passed to the function).
- ```sudo apt install -y $1```: Installs the required package if it’s missing.

### Install Required Packages
```bash
check_install nginx
check_install certbot
check_install python3-certbot-nginx
```
- **nginx**: A web server to host the static website.
- **certbot**: A tool to obtain and manage SSL certificates from Let's Encrypt.
- **python3-certbot-nginx**: A Certbot plugin for managing Nginx SSL configurations.

### Install AWS CLI v2
```
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
```
This checks if AWS CLI v2 is installed. If not, it downloads the AWS CLI installer, installs it using the install script and cleans up installation files to save disk space.

### Create Web Directory
```bash
if [ ! -d "/var/www/html" ]; then
    sudo mkdir -p /var/www/html
fi
```
This ensures the web directory exists (/var/www/html), where static files will be served by Nginx.
```mkdir -p```: Creates the directory and any parent directories if they don’t exist.

### Configure Nginx
```bash
sudo aws s3 cp "s3://${bucket_name}/${nginx_config_key}" /etc/nginx/sites-available/default
sudo sed -i "s/server_name _;/server_name ${domain_name};/g" /etc/nginx/sites-available/default
```
**Download Configuration:** Copies the Nginx configuration file (default) from the S3 bucket.
**Update Domain Name:** Replaces the placeholder server_name _; with the actual domain name.

# Configuring HTTPS using a free SSL Certificates

```bash
if [ -n "${domain_name}" ]; then
    # Certbot for domain-based SSL
    sudo certbot certonly --standalone -d ${domain_name} --non-interactive --agree-tos --email admin@${domain_name}
    sudo sed -i "s|/etc/letsencrypt/live/default/|/etc/letsencrypt/live/${domain_name}/|g" /etc/nginx/sites-available/default
else
    # Fallback to nip.io-based SSL
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    sudo certbot --nginx --register-unsafely-without-email --agree-tos -d $PUBLIC_IP.nip.io --non-interactive
fi
```
**Domain Name SSL**: If domain_name is provided, it uses Certbot in standalone mode to generate an SSL certificate for the domain.
**Updates Nginx configuration** to point to the certificate files.
**Fallback SSL**:If domain_name is not provided it uses the public IP address with a .nip.io domain (a wildcard DNS service) to generate an SSL certificate.

### Configure Certificate Renewal
```bash
if [ ! -f "/etc/cron.d/certbot-renew" ]; then
    echo "Setting up certificate renewal..."
    echo "0 12 * * * /usr/bin/certbot renew --quiet --post-hook '/bin/systemctl reload nginx'" | sudo tee /etc/cron.d/certbot-renew
    sudo chmod 600 /etc/cron.d/certbot-renew
fi
```
This chunk Adds a cron job to automatically renew SSL certificates every day at noon. After renewal, Nginx is reloaded to apply the updated certificates.

### Deploy Static Files earlier uploaded from S3
```bash
sudo aws s3 cp "s3://${bucket_name}/${html_key}" /var/www/html/index.html
sudo aws s3 cp "s3://${bucket_name}/${css_key}" /var/www/html/style.css
sudo aws s3 cp "s3://${bucket_name}/${js_key}" /var/www/html/script.js
```
This downloads static files (HTML, CSS, JS) from the specified S3 bucket and stores them in the /var/www/html directory.

### Update File Permissions
```bash
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
```
This ensures Nginx (running as www-data) owns the static files. It grants read/write/execute permissions to the owner and read/execute permissions to others.

### Restart Nginx
```bash
sudo systemctl enable nginx
sudo systemctl restart nginx
```
It ensures Nginx starts automatically on boot (enable). Restarts Nginx to apply the new configuration and serve the website.

### Final Message
```bash
echo "Setup completed successfully!"
```
Indicates that the setup process has finished without errors.

## Output blocks
Once the terraform commands for deployment (See deployment intructions), are run, the output block in Terraform will display information about resources after they are created. This can be useful for referencing key details (e.g., public IPs, bucket names, etc.) or sharing outputs with other modules.

***Public IP of the Web Server***
```hcl
output "public_ip" {
  value       = aws_eip.web_eip.public_ip
  description = "Public IP of the web server"
}
```
This outputs the public IP of the Elastic IP (aws_eip.web_eip) associated with the EC2 instance, which is required to access the instance over the internet.. This value will be dynamically generated when Terraform applies the configuration. This output is also required to ssh into the server when necessary for things like troubleshooting or manual adjustments. 

***Name of the Created S3 Bucket***
```hcl
output "bucket_name" {
  value       = aws_s3_bucket.static_files.id
  description = "Name of the created S3 bucket"
}
```
This references the the unique ID of the S3 bucket created earlier. The bucket ID is typically the same as its name. This outputs the name of the S3 bucket, which is helpful for tasks like uploading files manually or troubleshooting.

***SSL Domain***
```hcl
output "ssl_domain" {
  value       = var.domain_name != "" ? var.domain_name : "${aws_eip.web_eip.public_ip}.nip.io"
  description = "Domain name or IP used for SSL certificate"
}
```

This Uses a conditional expression to determine the domain used for the SSL certificate,  it decides which domain to use for SSL setup based on whether a custom domain was provided.

They are displayed in the terminal after terraform apply or terraform output.


# Deployment Instructions
### Initialize the Terraform project:
The first step is to initialize Terraform in your project directory. This sets up the required backend and downloads necessary provider plugins.
   ```bash
   terraform init
   ``` 

### Deploy only the Elastic IP:

```bash
terraform apply -target=aws_eip.web_eip
```

This command focuses on creating just the Elastic IP (EIP) resource from your Terraform configuration, without deploying the rest of the infrastructure. It is useful in scenarios where yYou need the public IP address for tasks like DNS setup before deploying other resources.

### Retrieve public IP 
This step is essential if you need the public IP to add to your DNS record and assign a domain name. You want to see the IP for SSH access to the server.

```bash
terraform output public_ip
```
### Add a DNS Record (Optional)
If you have a domain name and want to use it to access your web server, you need to add a DNS record to link the domain to the public IP of your web server (Elastic IP). This is a manual step. This allows users to access your website or application using a human-friendly domain name instead of the raw IP address.

You may have to take steps like 
- Log in to Your Domain Registrar to access your domain provider’s DNS management settings.
- Create a New A Record: 
     - Type: A, Name: @ (or www for a subdomain)
     - Value: The Elastic IP from Terraform output (e.g., 54.123.45.67).
     - TTL: (Optional) The time-to-live value, typically set to 3600 seconds (1 hour).
- Save the Record: Save the record and allow time for DNS propagation (can take a few minutes to hours)

### Deploy the full configuration:
**If you have added a DNS record for your custom domain, run:**

```bash
terraform apply -var="domain_name=example.com"
```
This replaces the default domain in your Terraform configuration (cloud.3figirl.com) with your custom domain (example.com). It also Configures SSL certificates for your domain using Certbot.

**If you dont have  a DNS record for your custom domain, run:**

 ```bash
 terraform apply
 ```
 Terraform will fall back to using the public IP of your server and create a temporary .nip.io domain for SSL.

 ###  Verify the Deployment
Once the deployment completes, Terraform will output essential information:
- Public IP: Use this to SSH into the server or configure your DNS.
- Bucket Name: S3 bucket name for static file management.
- SSL Domain: The domain (custom or .nip.io) configured for SSL.

### Terraform destroy
- After deplpoyment, don't forget to run ```terraform destroy``` to stop all resources and save cost. This means the website will be shut down

#### Remember to replace the statics with yours 

With this setup, you have a robust foundation for deploying secure, scalable web applications on AWS. It's a perfect starting point for building advanced infrastructure with Terraform! 🚀

# END OF DOC - Onward is TLDR and only for those who want to understand and replicate this deployment script
This part describe every line of code in the repository

# HTML Page Deployment
This is done within a terraform code (main.tf) to enable automation and reproducibility of assignment.  

### S3 Bucket Setup : 
Amazon S3 (Simple Storage Service) is a highly scalable storage solution for files, objects, and backups. Using Terraform, we can automate the creation and configuration of an S3 bucket. Let’s break down the code snippet into its components

The terraform block creates an S3 bucket with a globally unique name to storee the static frontend files - index.html, style.css, and script.js. It also Enables versioning to track file changes and Sets up lifecycle rules to delete old file versions after 1 day.

s3 Bucket Creation Block in AWS (The Terraform code can be cloned in my repository)

```yaml
resource "aws_s3_bucket" "static_files" {
  bucket        = "mariam-altschool-static-2024"
  force_destroy = true
``` 
**Key Points**

- ```resource "aws_s3_bucket"```: This is the resource block in Terraform. It tells Terraform to create an S3 bucket using the AWS provider.
- ```aws_s3_bucket```: This is the resource type. AWS S3 bucket resources are defined using this block.
- ```static_files```:This is the logical name you give to the resource in Terraform. You can reference this name elsewhere in the code.
- ```bucket = "globally unique name"```: The name of the S3 bucket must be globally unique across all AWS accounts and regions. Example: "my-static-files-1234".
- ```force_destroy = true```:Allows Terraform to delete the bucket even if it contains objects. ***Why?*** Normally, S3 buckets cannot be deleted if they contain files or objects.
When force_destroy is true, Terraform automatically deletes everything inside the bucket before deleting the bucket itself. This aids automation and reduces the need to manually remove resources

### Lifecycle Configuration : 
The lifecycle block controls how Terraform manages this resource during updates or deletions.

s3 Bucket Creation Block in AWS (The Terraform code can be cloned in my repository)

```hcl
lifecycle {
  prevent_destroy = false
  ignore_changes  = [tags, versioning]
}
``` 
**Key Points**

- ```prevent_destroy = false```: Allows the bucket to be deleted during a terraform destroy.
If prevent_destroy were set to true, Terraform would prevent accidental deletions of the bucket. ***Important Note***: Use ```prevent_destroy = true``` in production to protect critical resources.
- ```ignore_changes = [tags, versioning]```: Specifies the attributes Terraform should ignore when comparing the desired state to the actual state. Changes to ```tags``` and ```versioning``` won't trigger an update.
Why?
Sometimes, external tools (like the AWS console) update these fields.
Ignoring them avoids unnecessary Terraform drift (i.e., changes Terraform thinks it must correct).

### Lifecycle duration
Lifecycle configuration allows you to automatically manage the lifecycle of objects (files) in an S3 bucket. This includes actions like transitioning objects to cheaper storage classes (e.g., Glacier for archival). Deleting old or unused files after a certain time to save costs.
```hcl
resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  bucket = aws_s3_bucket.static_files.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}
```
This code specifically expires noncurrent versions of files after 1 day.
```resource "aws_s3_bucket_lifecycle_configuration"``` this configures lifecycle rules for an existing S3 bucket.
Resource Name: ```bucket_lifecycle``` is a logical resource name for internal Terraform reference.
```bucket = aws_s3_bucket.static_files.id```: This links this lifecycle configuration to the S3 bucket created earlier.

**The rule Block**
A rule defines what happens to objects over their lifecycle.
```id = "expire-old-versions"```: A unique identifier for this rule (helps identify and manage it later).
```status = "Enabled"```: Activates the rule. Without this, the rule is ignored.
```noncurrent_version_expiration Block```: Defines behavior for noncurrent (older) versions of files. ```noncurrent_days = 1``` specifies that older versions of files will be deleted after 1 day.

### Tags
Tags add metadata to the S3 bucket. Tags like Name and Environment make it easier to identify and manage the resource. Useful for cost tracking, filtering resources, and automated management with AWS tools.

```hcl
Example Tags:tags = {
    Name        = "Static Website Bucket"
    Environment = "Production"
  }
```

### Enabling Versioning

```hcl
resource "aws_s3_bucket_versioning" "static_files" {
  bucket = aws_s3_bucket.static_files.id

  versioning_configuration {
    status = "Enabled"
  }
}
```
This step enables versioning for the S3 bucket. Keeps a history of all versions of objects hence it rotects against accidental deletions or overwrites which is useful for recovery in production.

### Making the Bucket Private
This step ensures the S3 bucket is completely private by blocking all forms of public access.
```hcl
resource "aws_s3_bucket_public_access_block" "static_files" {
  bucket = aws_s3_bucket.static_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```
```block_public_acls = true```: Prevents users from setting public Access Control Lists (ACLs). ```block_public_policy = true```:Blocks public bucket policies. ```ignore_public_acls = true```:Ignores any public ACLs already applied to the bucket.
```restrict_public_buckets = true```:Restricts all public access, even if someone tries to override the settings.
By default, S3 buckets can be misconfigured to expose data publicly. These settings ensure the bucket is fully private, which is critical for sensitive data or production environments.


### Uploading static files as s3 objects
The aws_s3_object resource represents a single file that you want to upload to an S3 bucket. Each file will have a key (its name in the bucket), source (where it is on your system), and metadata (e.g., content type).

**Html code sample object**

```hcl
resource "aws_s3_object" "html_file" {
  bucket = aws_s3_bucket.static_files.id
  key    = "index.html"
  source = "index.html"
  content_type = "text/html"
  etag = filemd5("index.html")
}
```
- ```bucket``` This specifies the target S3 bucket where the file will be uploaded.
- ```Value: aws_s3_bucket.static_files.id```: dynamically references the ID of the S3 bucket created elsewhere in your configuration.
- ```key``` Defines the name of the file in the bucket. This name is used to access the file in the bucket (e.g., index.html will be stored as https://<bucket-name>.s3.amazonaws.com/index.html).
- ```source``` This points to the local file on your machine that you want to upload.
Example: If you’re uploading index.html, the source should be the path to index.html on your system.
- ```content_type```: This specifies the file type (MIME type) for the uploaded object. It ensures the file is interpreted correctly by browsers or applications. For example:
     - text/html → Web browsers treat it as an HTML page.
     - text/css → Interpreted as a CSS stylesheet.
     - application/javascript → Treated as a JavaScript file.
- ```etag```: Adds a hash (MD5 checksum) of the file using the filemd5() function. It ensures the file is uploaded only if its content has changed. Avoids unnecessary uploads, making deployments faster and more efficient.

# Provisioning the server

### Creating the IAM Role and Instance Profile with Policies
This Terraform code creates an IAM role for EC2 instances, an instance profile, and attaches a policy that grants specific permissions to the role. 

1. **IAM Role (aws_iam_role):** An IAM Role is a set of permissions that AWS resources (like EC2 instances) can assume to perform actions.In this case, the role allows EC2 instances to:
    - Log events to CloudWatch Logs.
    - Access objects from an S3 bucket.

```hcl
resource "aws_iam_role" "ec2_role" {
  name = "altschool-ec2-role" 
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  lifecycle {
    prevent_destroy = false
    ignore_changes = [tags]
  }
}
``` 

- ```name = "altschool-ec2-role"```: Assigns a fixed name to the role. Useful for identifying it in the AWS Console or other resources.
- ```assume_role_policy```: Specifies who can assume the role (in this case, EC2 instances).

**Policy Details:**
- ```Action```: Specifies ```sts:AssumeRole```, which allows the service to "assume" this role.
- ```Principal```: Specifies that EC2 instances (```ec2.amazonaws.com```) are allowed to assume the role.
- ```Effect```: Set to Allow to grant the permission.

**lifecycle Block**
```prevent_destroy = false```: Allows Terraform to delete the role when you run terraform destroy.
```ignore_changes = [tags]```: Ignores manual changes to tags outside of Terraform to prevent unnecessary updates.

2. ```Instance Profile (aws_iam_instance_profile)```: Instance Profiles are used to associate IAM roles with EC2 instances. EC2 instances need an instance profile to use the permissions defined in the role.
```
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "altschool-ec2-profile"
  role = aws_iam_role.ec2_role.name

  lifecycle {
    prevent_destroy = false
  }
}
```

- ```name = "altschool-ec2-profile"```: Assigns a fixed name to the instance profile, making it easy to reference.
- ```role = aws_iam_role.ec2_role.name```:Links this instance profile to the IAM role created earlier (altschool-ec2-role).

**lifecycle Block**

- ```prevent_destroy = false```: Allows Terraform to delete the instance profile during terraform destroy.

**3. IAM Role Policy (aws_iam_role_policy)**: Attaches a policy to the IAM role. The policy defines what actions the EC2 instance can perform and on what resources.
```hcl
resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "*",
          aws_s3_bucket.static_files.arn,
          "${aws_s3_bucket.static_files.arn}/*"
        ]
      }
    ]
  })
}
```
- ```name = "ec2_policy"```: Assigns a name to the policy for easy identification.
- ```role = aws_iam_role.ec2_role.id```: Associates this policy with the IAM role (altschool-ec2-role).
- ```policy```: Encodes the permissions in JSON format.

**Policy Details**
- ```Effect = "Allow"```: Grants permission to perform actions.
- ```Action```: Specifies the actions the role can perform

**CloudWatch Logs**:
- ```logs:CreateLogGroup```: Create log groups. logs:CreateLogStream: Create log streams.
- ```logs:PutLogEvents```: Send log data to CloudWatch.

**S3:**
- ```s3:GetObject```: Read objects from the S3 bucket.
- ```s3:ListBucket```: List objects in the bucket.

**Resource**
Defines the resources these permissions apply to:
- ```"*"```: Grants access to all resources (not recommended for production).
- ```aws_s3_bucket.static_files.arn```: Grants access to the specific S3 bucket.
- ``"${aws_s3_bucket.static_files.arn}/*"``: Grants access to all objects within the bucket.

### Security Group
A security group acts as a virtual firewall for your EC2 instance, controlling inbound (ingress) and outbound (egress) traffic. In this case, the security group: Allows HTTP (port 80), HTTPS (port 443), and SSH (port 22) traffic and Permits all outbound traffic.

```hcl
resource "aws_security_group" "web_sg" {
  name        = "altschool-web-sg"
  description = "Allow HTTP, HTTPS and SSH traffic"

  lifecycle {
    prevent_destroy = false
    create_before_destroy = true
    ignore_changes = [
      description,
      tags
    ]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  // .... rest of code in repo

  }
}
```

name and description

name: Assigns a fixed name (altschool-web-sg) to the security group, making it easier to identify in the AWS console.
description: Explains the purpose of the security group.
lifecycle Block

prevent_destroy = false: Allows the security group to be deleted when you run terraform destroy.
create_before_destroy = true: Ensures a new security group is created before destroying the old one, preventing downtime during updates.
ignore_changes: Tells Terraform to ignore changes to the description and tags fields made outside of Terraform.
ingress Blocks

Define rules for inbound traffic:
Port 22 (SSH): Allows secure remote access.
Port 80 (HTTP): Enables access to the web server via a browser.
Port 443 (HTTPS): Supports secure web traffic.
cidr_blocks = ["0.0.0.0/0"]: Allows traffic from any IP address. In production, you should restrict this to specific IPs for security.
egress Block

Defines rules for outbound traffic:
Allows all outbound traffic (from_port = 0, to_port = 0, protocol = "-1").

### Key Pair (aws_key_pair)
A key pair is used to securely SSH into your EC2 instance. The public key is stored in AWS, while the private key is kept on your machine for authentication.

key_name

Assigns a name to the key pair (mariamhostspace). This name will be referenced in your EC2 instance configuration.
public_key

Specifies the path to your public key file (mariamhostspace.pub).
Ensure File Exists: The public key must already exist in your project directory. Use ssh-keygen to generate it if you don’t have one.
How to Generate a Key Pair
Open your terminal or command prompt.

Run the following command to generate a new SSH key pair:

bash
ssh-keygen -t rsa -b 2048 -f mariamhostspace
This will create:

A private key: mariamhostspace.pem
A public key: mariamhostspace.pub
Ensure the .pem file has the correct permissions:

bash
chmod 400 mariamhostspace.pem


### Creating EC2 Instance and Elastic IP Configuration to host website on (CDN can be originally used to host statics)
This Terraform configuration deploys an EC2 instance with necessary configurations and an Elastic IP (EIP) for consistent public access. It references other resources such as an IAM instance profile, security group, and S3 objects previously created.

**1. EC2 Instance (aws_instance)**: The EC2 instance serves as the web server hosting your application. It references:
- A security group for access control.
- An IAM instance profile for permissions.
- S3 objects for static files and Nginx configuration.
```
resource "aws_instance" "web_server" {
  depends_on = [
    aws_iam_instance_profile.ec2_profile,
    aws_security_group.web_sg,
    aws_s3_object.nginx_config
  ]
  // break code here for explanation 

  ``` 
```depends_on```: Ensures the instance is created only after the listed resources are available:
- IAM instance profile (ec2_profile): For permissions.
- Security group (web_sg): For network access control.
- S3 object (nginx_config): Ensures configuration is ready before instance creation.

  ```
  ami           = "ami-0e2c8caa4b6378d8c"
  instance_type = "t2.micro"              
  key_name      = aws_key_pair.deployer.key_name  // Reference the created key pair
  vpc_security_group_ids = [aws_security_group.web_sg.id]  // Direct reference
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name  // Direct reference

  // break code here for explanation 
  ```
 **```ami```**: Specifies the Amazon Machine Image (AMI) to use for the instance. The AMI determines the operating system and base configuration for the EC2 instance.
- ```instance_type```: Specifies the size of the instance. Determines the compute, memory, and network capacity.
- ```key_name```: References the name of an existing key pair for SSH access to the instance.
- ```vpc_security_group_ids```: Associates the instance with a security group (web_sg), controlling inbound and outbound traffic.
- ```iam_instance_profile```: Links the EC2 instance to the IAM instance profile, granting it the permissions defined in the IAM role.

  ```
  user_data = base64encode(templatefile("install_webserver.sh", {
    bucket_name = aws_s3_bucket.static_files.id
    html_key    = aws_s3_object.html_file.key
    css_key     = aws_s3_object.css_file.key
    js_key      = aws_s3_object.js_file.key
    nginx_config_key = aws_s3_object.nginx_config.key
    domain_name = var.domain_name
  }))
  break code here for explanation
  ```
- **```user_data```**: Runs the bash script (install_webserver.sh, defined later in this doc) during the instance's startup. It downloads static files (HTML, CSS, JavaScript, Nginx config) from the S3 bucket and configures and starts the web server.
- ```templatefile:``` Replaces placeholders in install_webserver.sh with actual values like: ```bucket_name```: The name of the S3 bucket, ```html_key```, ```css_key```, ```js_key```: Keys of the static files in S3, ```nginx_config_key```: Key for the Nginx configuration file, ```domain_name:``` Custom domain name for the web server.

```
  lifecycle {
    create_before_destroy = true
    ignore_changes = [tags]
  }

  tags = {
    Name = "Altschool-Web-Server-Project"
  }
}
```
**lifecycle**
- ```create_before_destroy = true```: Ensures a new instance is created before destroying the old one during updates.
- ```ignore_changes = [tags]```: Ignores changes to tags outside Terraform, avoiding unnecessary updates.
- ```tags```: Adds metadata for the instance, making it easier to identify in the AWS console.


**2. Elastic IP (aws_eip)**: An Elastic IP provides a static public IP address for the EC2 instance. This ensures the web server's IP does not change, even if the instance is stopped and restarted.

```hcl
resource "aws_eip" "web_eip" {
  instance = aws_instance.web_server.id
  domain   = "vpc"
}
```
- ```instance```: Links the Elastic IP to the EC2 instance (web_server).
- ```domain```: Specifies the networking domain. For VPC instances, this is always "vpc".
- ```Dependencies```: The depends_on block ensures all prerequisites (IAM role, security group, S3 objects) are in place before the instance is created.

### SSH_Resource

SSH (Secure Shell) is a protocol for securely connecting to remote machines and running commands.. The SSH resource executes commands directly on the EC2 instance after it has been deployed. This is useful for: Copying files to the instance, Running installation and configuration scripts (e.g., setting up Nginx), Restarting services (e.g., Nginx) after updates, etc

```hcl
resource "ssh_resource" "web_init" {
  depends_on = [aws_instance.web_server]
  
  host = aws_eip.web_eip.public_ip
  user = "ubuntu"
  private_key = file("mariamhostspace.pem")

  timeout = "5m"
  retry_delay = "5s"

```
- ```depends_on```
What it does: Ensures that the EC2 instance is fully created before running any commands via SSH.
- ```host```: Specifies the public IP address of the EC2 instance for the SSH connection.
- ```aws_eip.web_eip.public_ip```: The Elastic IP ensures a consistent IP address that remains the same even if the instance is restarted.
- ```user```: Specifies the username used to connect to the EC2 instance. For Ubuntu instances, this is usually "ubuntu".
- ```private_key```:Provides the private key for authentication. The private key file must match the key pair used when creating the EC2 instance.
- ```timeout & retry_delay```: ```timeout``` Specifies the maximum time to wait for the commands to complete (5 minutes in this case). ```retry_delay``` specifies the delay between retries if the connection fails (5 seconds here).

### Commands for the ssh resource block
These are the effective commands that are run on the resource after its deployment
```hcl
commands = [
    "sleep 60",
    # Copy and execute install_webserver.sh with the nginx config
    "echo '${templatefile("install_webserver.sh", {
      bucket_name = aws_s3_bucket.static_files.id
      html_key    = aws_s3_object.html_file.key
      css_key     = aws_s3_object.css_file.key
      js_key      = aws_s3_object.js_file.key
      nginx_config_key = aws_s3_object.nginx_config.key
      domain_name = var.domain_name
    })}' > /tmp/install_webserver.sh",
    "chmod +x /tmp/install_webserver.sh",
    "sudo /tmp/install_webserver.sh",
    
    # Additional file updates if needed
    "sudo aws s3 cp s3://${aws_s3_bucket.static_files.id}/${aws_s3_object.html_file.key} /var/www/html/",
    "sudo aws s3 cp s3://${aws_s3_bucket.static_files.id}/${aws_s3_object.css_file.key} /var/www/html/",
    "sudo aws s3 cp s3://${aws_s3_bucket.static_files.id}/${aws_s3_object.js_file.key} /var/www/html/",
    "sudo chown -R www-data:www-data /var/www/html",
    "sudo chmod -R 755 /var/www/html",
    "sudo systemctl restart nginx"
  ]
```
- ```sleep 60```: Waits 60 seconds to ensure the instance is fully initialized before executing commands.
- ***Install Web Server***: Copies and executes install_webserver.sh: ```The templatefile()``` function replaces placeholders in install_webserver.sh with actual values (e.g., bucket name, file keys). The script is then uploaded to /tmp/install_webserver.sh, made executable, and executed using sudo.
- ***Additional File Updates***: Downloads files (HTML, CSS, JavaScript) from the S3 bucket to the instance: ```aws s3 cp s3://<bucket>/<key> <local-path>```
- Sets permissions:
     - chown -R www-data:www-data: Ensures the web server (Nginx) owns the files.
     - chmod -R 755: Grants appropriate permissions for the files.
***Restart Nginx*** Restarts the Nginx web server to apply changes.

### Triggers
Ensures the ssh_resource is re-applied if any of the S3 objects (HTML, CSS, JS, or Nginx config) are updated. he etag field is a unique hash of the file contents. If the file changes, the hash changes, triggering the SSH commands to run again.

```
 triggers = {
    html_etag = aws_s3_object.html_file.etag
    css_etag = aws_s3_object.css_file.etag
    js_etag = aws_s3_object.js_file.etag
    nginx_config_etag = aws_s3_object.nginx_config.etag
  }
}
```

# Networking 

### Domain name assignment
This variable block defines a variable named domain_name, which is used to specify the domain name for the SSL certificate in your Terraform configuration.

```hcl
variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = "cloud.3figirl.com"  # Will use public IP if no domain provided
}
```
- ```variable "domain_name"```: Declares a variable named domain_name that can be used throughout the Terraform project.
- ```description```: Describes the purpose of the variable to improve readability and understanding.
```type = string```: Specifies that the variable must be a string (text value).
```default = "cloud.3figirl.com"``` Default Value: If no value is provided on terraform apply, the variable defaults to ```"cloud.3figirl.com"```
Overiding the defaut can be done by running ``terraform apply -var="domain_name=example.com"``


### Output blocks
The output block in Terraform is used to display information about resources after they are created. This can be useful for referencing key details (e.g., public IPs, bucket names, etc.) or sharing outputs with other modules.

***Public IP of the Web Server***
```hcl
output "public_ip" {
  value       = aws_eip.web_eip.public_ip
  description = "Public IP of the web server"
}
```
This outputs the public IP of the Elastic IP (aws_eip.web_eip) associated with the EC2 instance, which is required to access the instance over the internet.. This value will be dynamically generated when Terraform applies the configuration. This output is also required to ssh into the server when necessary for things like troubleshooting or manual adjustments. 

***Name of the Created S3 Bucket***
```hcl
output "bucket_name" {
  value       = aws_s3_bucket.static_files.id
  description = "Name of the created S3 bucket"
}
```
This references the the unique ID of the S3 bucket created earlier. The bucket ID is typically the same as its name. This outputs the name of the S3 bucket, which is helpful for tasks like uploading files manually or troubleshooting.

***SSL Domain***
```hcl
output "ssl_domain" {
  value       = var.domain_name != "" ? var.domain_name : "${aws_eip.web_eip.public_ip}.nip.io"
  description = "Domain name or IP used for SSL certificate"
}
```

This Uses a conditional expression to determine the domain used for the SSL certificate,  it decides which domain to use for SSL setup based on whether a custom domain was provided.

They are displayed in the terminal after terraform apply or terraform output.


# Web Server Setup

### BASH Script - Installation and Updates

This script automates the setup of an Nginx-based web server, including installing necessary packages, setting up SSL certificates, configuring Nginx, and deploying static files from an S3 bucket.

### Script Setup
```bash
#!/bin/bash
set -e
```
- ```#!/bin/bash```: Specifies that this script will run in the Bash shell.
- ```set -e```: Causes the script to exit immediately if any command fails, ensuring that errors are handled without proceeding to subsequent steps.


### Function to Check and Install Packages
```bash
check_install() {
    if ! command -v $1 &> /dev/null; then
        echo "Installing $1..."
        sudo apt update -y
        sudo apt install -y $1
    else
        echo "$1 is already installed"
    fi
}
```

- ```check_install()```: A reusable function to check if a package is installed and install it if it’s not.
- ```command -v $1```: Checks if the given command exists in the system ($1 is the argument passed to the function).
- ```sudo apt install -y $1```: Installs the required package if it’s missing.

### Install Required Packages
```bash
check_install nginx
check_install certbot
check_install python3-certbot-nginx
```
- **nginx**: A web server to host the static website.
- **certbot**: A tool to obtain and manage SSL certificates from Let's Encrypt.
- **python3-certbot-nginx**: A Certbot plugin for managing Nginx SSL configurations.

### Install AWS CLI v2
```
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
```
This checks if AWS CLI v2 is installed. If not, it downloads the AWS CLI installer, installs it using the install script and cleans up installation files to save disk space.

### Create Web Directory
```bash
if [ ! -d "/var/www/html" ]; then
    sudo mkdir -p /var/www/html
fi
```
This ensures the web directory exists (/var/www/html), where static files will be served by Nginx.
```mkdir -p```: Creates the directory and any parent directories if they don’t exist.

### Configure Nginx
```bash
sudo aws s3 cp "s3://${bucket_name}/${nginx_config_key}" /etc/nginx/sites-available/default
sudo sed -i "s/server_name _;/server_name ${domain_name};/g" /etc/nginx/sites-available/default
```
**Download Configuration:** Copies the Nginx configuration file (default) from the S3 bucket.
**Update Domain Name:** Replaces the placeholder server_name _; with the actual domain name.

# Configuring HTTPS using a free SSL Certificates

```bash
if [ -n "${domain_name}" ]; then
    # Certbot for domain-based SSL
    sudo certbot certonly --standalone -d ${domain_name} --non-interactive --agree-tos --email admin@${domain_name}
    sudo sed -i "s|/etc/letsencrypt/live/default/|/etc/letsencrypt/live/${domain_name}/|g" /etc/nginx/sites-available/default
else
    # Fallback to nip.io-based SSL
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    sudo certbot --nginx --register-unsafely-without-email --agree-tos -d $PUBLIC_IP.nip.io --non-interactive
fi
```
**Domain Name SSL**: If domain_name is provided, it uses Certbot in standalone mode to generate an SSL certificate for the domain.
**Updates Nginx configuration** to point to the certificate files.
**Fallback SSL**:If domain_name is not provided it uses the public IP address with a .nip.io domain (a wildcard DNS service) to generate an SSL certificate.

### Configure Certificate Renewal
```bash
if [ ! -f "/etc/cron.d/certbot-renew" ]; then
    echo "Setting up certificate renewal..."
    echo "0 12 * * * /usr/bin/certbot renew --quiet --post-hook '/bin/systemctl reload nginx'" | sudo tee /etc/cron.d/certbot-renew
    sudo chmod 600 /etc/cron.d/certbot-renew
fi
```
This chunk Adds a cron job to automatically renew SSL certificates every day at noon. After renewal, Nginx is reloaded to apply the updated certificates.

### Deploy Static Files from S3
```bash
sudo aws s3 cp "s3://${bucket_name}/${html_key}" /var/www/html/index.html
sudo aws s3 cp "s3://${bucket_name}/${css_key}" /var/www/html/style.css
sudo aws s3 cp "s3://${bucket_name}/${js_key}" /var/www/html/script.js
```
This downloads static files (HTML, CSS, JS) from the specified S3 bucket and stores them in the /var/www/html directory.

### Update File Permissions
```bash
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
```
This ensures Nginx (running as www-data) owns the static files. It grants read/write/execute permissions to the owner and read/execute permissions to others.


### Restart Nginx
```bash
sudo systemctl enable nginx
sudo systemctl restart nginx
```

It ensures Nginx starts automatically on boot (enable). Restarts Nginx to apply the new configuration and serve the website.

### Final Message
```bash
echo "Setup completed successfully!"
```
Indicates that the setup process has finished without errors.


