provider "aws" {
  region = "us-east-1"
}

// S3 bucket with fixed name and versioning
resource "aws_s3_bucket" "static_files" {
  bucket        = "mariam-altschool-static-2024"  // Fixed name
  force_destroy = true

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      tags,
      versioning  // Fixed attribute name
    ]
  }

  tags = {
    Name        = "Static Website Bucket"
    Environment = "Production"
  }
}

// Enable versioning
resource "aws_s3_bucket_versioning" "static_files" {
  bucket = aws_s3_bucket.static_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

// Make bucket private
resource "aws_s3_bucket_public_access_block" "static_files" {
  bucket = aws_s3_bucket.static_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// Add lifecycle configuration
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

resource "aws_s3_object" "html_file" {
  bucket = aws_s3_bucket.static_files.id
  key    = "index.html"
  source = "index.html"
  content_type = "text/html"
  etag = filemd5("index.html")
}

resource "aws_s3_object" "css_file" {
  bucket = aws_s3_bucket.static_files.id
  key    = "style.css"
  source = "style.css"
  content_type = "text/css"
  etag = filemd5("style.css")
}

resource "aws_s3_object" "js_file" {
  bucket = aws_s3_bucket.static_files.id
  key    = "script.js"
  source = "script.js"
  content_type = "application/javascript"
  etag = filemd5("script.js")
}

// IAM role with fixed name
resource "aws_iam_role" "ec2_role" {
  name = "altschool-ec2-role"  // Fixed name

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

// Instance profile with fixed name
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "altschool-ec2-profile"
  role = aws_iam_role.ec2_role.name

  lifecycle {
    prevent_destroy = false
  }
}

// Update policy to use the correct role
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

// Security group with fixed name
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

// Add key pair resource
resource "aws_key_pair" "deployer" {
  key_name   = "mariamhostspace"
  public_key = file("mariamhostspace.pub")  // Make sure this file exists in your project directory
}

// EC2 instance with direct references
resource "aws_instance" "web_server" {
  ami           = "ami-0e2c8caa4b6378d8c"  // Updated AMI
  instance_type = "t2.micro"               // Changed from t3.micro
  key_name      = aws_key_pair.deployer.key_name  // Reference the created key pair
  vpc_security_group_ids = [aws_security_group.web_sg.id]  // Direct reference
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name  // Direct reference

  user_data = base64encode(templatefile("install_webserver.sh", {
    bucket_name = aws_s3_bucket.static_files.id
    html_key    = aws_s3_object.html_file.key
    css_key     = aws_s3_object.css_file.key
    js_key      = aws_s3_object.js_file.key
  }))

  lifecycle {
    create_before_destroy = true
    ignore_changes = [tags]
  }

  tags = {
    Name = "Altschool-Web-Server-Project"
  }
}

resource "aws_eip" "web_eip" {
  instance = aws_instance.web_server.id
  domain   = "vpc"
}

// Outputs
output "public_ip" {
  value = aws_eip.web_eip.public_ip
  description = "Public IP of the web server"
}

output "bucket_name" {
  value = aws_s3_bucket.static_files.id
  description = "Name of the created S3 bucket"
}
