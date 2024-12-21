# Terraform-Based Web Server Setup with SSL and Static Files



This guide explains how to deploy a secure and automated web server on AWS using Terraform, an EC2 instance, and Nginx. Static files are served from a provisioned S3 bucket, and SSL certificates are automatically provisioned using Let's Encrypt. Installations and updates are done in a bash script that is executed from the terraform automation. 
By the end of this guide, you will have a fully configured HTTPS-enabled web server with automated deployment.


What you'll need before starting, ensure you have the following:
- AWS Account: Required to create resources (EC2, S3, IAM, etc).
- Terraform Installed: Download Terraform.
- AWS CLI Installed: Install AWS CLI 
- IAM User with Terraform Permissions: A single IAM user policy grants permissions to manage EC2, S3, and IAM resources.
- AWS CLI Configuration: The IAM user's access and secret keys are configured locally to authenticate Terraform commands.
- SSH Key Pair: Create
